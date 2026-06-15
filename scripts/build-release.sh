#!/usr/bin/env bash
# build-release.sh — build, deep-sign, (optionally) notarize, staple, and package
# CopyParty.app. One engine for every flavor; behaviour is set via env vars.
#
# Why a dedicated script (not Xcode signing): the app embeds a full CPython
# runtime — ~85 .dylib/.so files plus the native python3.12 — that Xcode's
# normal signing leaves untouched in Resources/. Notarization requires EVERY
# Mach-O to be Developer ID-signed with the hardened runtime, signed inside-out,
# then the whole app submitted to Apple and stapled.
#
# Env knobs (all optional):
#   ARCHS       xcodebuild archs, space-separated   (default "arm64"; universal: "arm64 x86_64")
#   SIGN_MODE   developer-id | adhoc                (default developer-id)
#   NOTARIZE    1 | 0                               (default 1 for developer-id; forced 0 for adhoc)
#   LABEL       artifact filename suffix            (e.g. universal, arm64, adhoc)
#   MAKE_DMG    1 | 0                               (default 1)
#   MAKE_ZIP    1 | 0                               (default 1)
#   CODESIGN_IDENTITY / TEAM_ID / NOTARY_PROFILE    (Developer ID overrides)
#
# The embedded runtime arch must match ARCHS — run fetch-vendor.sh / thin-vendor.sh
# first. Day-to-day dev signing in project.yml is left untouched.
set -euo pipefail

# ── Config ───────────────────────────────────────────────────────────────────
ARCHS="${ARCHS:-arm64}"
SIGN_MODE="${SIGN_MODE:-developer-id}"
LABEL="${LABEL:-}"
MAKE_DMG="${MAKE_DMG:-1}"
MAKE_ZIP="${MAKE_ZIP:-1}"
IDENTITY="${CODESIGN_IDENTITY:-Developer ID Application: Brielle Harrison (4HK2NGRWKW)}"
TEAM_ID="${TEAM_ID:-4HK2NGRWKW}"
NOTARY_PROFILE="${NOTARY_PROFILE:-CopyParty-Notary}"
SCHEME="CopyParty"
CONFIG="Release"

case "$SIGN_MODE" in
  developer-id) HARDENED=1; TIMESTAMP=1; NOTARIZE="${NOTARIZE:-1}" ;;
  adhoc)        IDENTITY="-"; HARDENED=0; TIMESTAMP=0; NOTARIZE=0 ;;
  *) echo "ERROR: SIGN_MODE must be developer-id or adhoc" >&2; exit 1 ;;
esac

SRCROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SRCROOT"
BUILD_DIR="$SRCROOT/build-release"
APP_NAME="CopyParty.app"
ENTITLEMENTS="$SRCROOT/CopyParty.entitlements"
VERSION="$(grep -m1 'MARKETING_VERSION' project.yml | sed 's/.*: *"\(.*\)".*/\1/')"
BASE="CopyParty-$VERSION${LABEL:+-$LABEL}"

echo "==> CopyParty $VERSION  [$SIGN_MODE, archs: $ARCHS, label: ${LABEL:-none}]"
echo "    identity: $IDENTITY  hardened: $HARDENED  notarize: $NOTARIZE"

# codesign wrapper honouring the flavor's flags. $2 = with-entitlements|plain
sign_file() {
  local f="$1" ent="${2:-plain}"
  local flags=(--force --sign "$IDENTITY")
  [[ "$HARDENED"  == "1" ]] && flags+=(--options runtime)
  [[ "$TIMESTAMP" == "1" ]] && flags+=(--timestamp)
  [[ "$ent" == "with-entitlements" ]] && flags+=(--entitlements "$ENTITLEMENTS")
  codesign "${flags[@]}" "$f"
}

# ── 1. Build (unsigned; we sign everything ourselves) ────────────────────────
echo "==> Regenerating Xcode project"
xcodegen generate

echo "==> Building $CONFIG (unsigned — manual deep-sign follows)"
DERIVED="$BUILD_DIR/DerivedData"
xcodebuild \
  -project CopyParty.xcodeproj \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -derivedDataPath "$DERIVED" \
  ARCHS="$ARCHS" ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  clean build

BUILT_APP="$DERIVED/Build/Products/$CONFIG/$APP_NAME"
[[ -d "$BUILT_APP" ]] || { echo "ERROR: build produced no app at $BUILT_APP"; exit 1; }

STAGE="$BUILD_DIR/stage"
rm -rf "$STAGE"; mkdir -p "$STAGE"
cp -R "$BUILT_APP" "$STAGE/"
APP="$STAGE/$APP_NAME"
RES="$APP/Contents/Resources"

echo "    embedded python: $(lipo -archs "$RES/python/bin/python3.12" 2>/dev/null || echo '?')"

# ── 2. Deep-sign all embedded Mach-O, inside-out ─────────────────────────────
echo "==> Signing embedded libraries (.dylib / .so)"
n=0
while IFS= read -r -d '' f; do sign_file "$f" plain; n=$((n + 1)); done \
  < <(find "$RES" -type f \( -name "*.dylib" -o -name "*.so" \) -print0)
echo "    signed $n libraries"

echo "==> Signing embedded executables (python/bin)"
n=0
while IFS= read -r -d '' f; do
  if file -b "$f" | grep -q "Mach-O"; then sign_file "$f" with-entitlements; n=$((n + 1)); fi
done < <(find "$RES/python/bin" -type f ! -name "*.dylib" ! -name "*.so" -print0)
echo "    signed $n executables"

echo "==> Signing app bundle"
sign_file "$APP" with-entitlements

echo "==> Verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP"
codesign -dvv "$APP" 2>&1 | grep -E "Authority=|TeamIdentifier=|flags=" || true

# ── 3. Notarize + staple (developer-id only) ─────────────────────────────────
DIST="$BUILD_DIR/dist"
rm -rf "$DIST"; mkdir -p "$DIST"

if [[ "$NOTARIZE" == "1" ]]; then
  echo "==> Submitting app to Apple notary service (profile: $NOTARY_PROFILE)"
  NOTARY_ZIP="$BUILD_DIR/notary.zip"; rm -f "$NOTARY_ZIP"
  ditto -c -k --keepParent "$APP" "$NOTARY_ZIP"
  xcrun notarytool submit "$NOTARY_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
  echo "==> Stapling app"
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
  spctl -a -vvv "$APP" || true
else
  echo "==> Not notarizing ($SIGN_MODE) — artifact is signed but not notarized"
fi

# ── 4. Package ───────────────────────────────────────────────────────────────
if [[ "$MAKE_ZIP" == "1" ]]; then
  echo "==> Packaging zip"
  ditto -c -k --keepParent "$APP" "$DIST/$BASE.zip"
fi

if [[ "$MAKE_DMG" == "1" ]]; then
  echo "==> Packaging dmg"
  DMG_OUT="$DIST/$BASE.dmg"
  DMG_SRC="$BUILD_DIR/dmg-src"; rm -rf "$DMG_SRC"; mkdir -p "$DMG_SRC"
  cp -R "$APP" "$DMG_SRC/"
  if create-dmg \
      --volname "CopyParty $VERSION" --window-size 540 380 --icon-size 128 \
      --icon "$APP_NAME" 140 200 --app-drop-link 400 200 --hdiutil-quiet \
      "$DMG_OUT" "$DMG_SRC" 2>/dev/null; then
    echo "    created via create-dmg"
  else
    echo "    create-dmg failed, falling back to hdiutil"
    rm -f "$DMG_OUT"
    hdiutil create -volname "CopyParty $VERSION" -srcfolder "$DMG_SRC" -ov -format UDZO "$DMG_OUT"
  fi
  if [[ "$NOTARIZE" == "1" ]]; then
    echo "==> Notarizing + stapling dmg"
    xcrun notarytool submit "$DMG_OUT" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG_OUT"
    xcrun stapler validate "$DMG_OUT"
  fi
fi

echo
echo "==> Done ($BASE). Artifacts in $DIST:"
ls -lh "$DIST"
