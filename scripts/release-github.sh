#!/usr/bin/env bash
#
# release-github.sh — build all distribution flavors and publish a GitHub release.
#
# Produces three flavors of CopyParty.app (version read from project.yml):
#   • universal — arm64+x86_64, Developer ID signed + notarized   (.dmg + .zip)
#   • arm64     — Apple Silicon only, Developer ID + notarized     (.dmg + .zip)
#   • adhoc     — universal, ad-hoc signed, NOT notarized          (.zip)
#
# Pipeline (no re-downloads between flavors):
#   1. fetch a universal Vendor/python (both arches, lipo-merged)
#   2. build universal notarized + universal adhoc from it
#   3. lipo-thin the runtime to arm64 and build the arm64 notarized flavor
#
# Publishing is gated: the build runs unconditionally; the GitHub release is only
# created when PUBLISH=1. Without it you get a dry run (artifacts + the gh command).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"
PUBLISH="${PUBLISH:-0}"

VERSION="$(grep -m1 'MARKETING_VERSION' project.yml | sed 's/.*: *"\(.*\)".*/\1/')"
TAG="v$VERSION"
OUT="$REPO_ROOT/build-release/release-$VERSION"
DIST="$REPO_ROOT/build-release/dist"
rm -rf "$OUT"; mkdir -p "$OUT"

log()    { printf '\n\033[1;35m######## %s\033[0m\n' "$*"; }
collect(){ cp "$DIST"/* "$OUT"/; }

log "CopyParty $VERSION — building all release flavors"

# 1. universal runtime (downloads both arches once, lipo-merges)
VENDOR_ARCH=universal scripts/fetch-vendor.sh

# 2a. universal, notarized (dmg + zip)
log "flavor: universal (notarized)"
ARCHS="arm64 x86_64" SIGN_MODE=developer-id NOTARIZE=1 LABEL=universal scripts/build-release.sh
collect

# 2b. universal, ad-hoc (zip only) — same runtime still in place
log "flavor: adhoc (ad-hoc signed, universal, not notarized)"
ARCHS="arm64 x86_64" SIGN_MODE=adhoc LABEL=adhoc MAKE_DMG=0 scripts/build-release.sh
collect

# 3. thin the runtime to arm64 and build the Apple-Silicon-only flavor
log "flavor: arm64 (notarized)"
scripts/thin-vendor.sh arm64
ARCHS="arm64" SIGN_MODE=developer-id NOTARIZE=1 LABEL=arm64 scripts/build-release.sh
collect

# ── Release notes: pull this version's section out of CHANGELOG.md ────────────
NOTES="$OUT/release-notes.md"
awk -v ver="$VERSION" '
  $0 ~ "^## \\[" ver "\\]" {grab=1; next}
  grab && /^## \[/ {exit}
  grab {print}
' CHANGELOG.md > "$NOTES"
{
  echo
  echo "### Downloads"
  echo "- **universal** — runs on Intel + Apple Silicon, notarized (recommended)."
  echo "- **arm64** — Apple Silicon only, notarized, smaller download."
  echo "- **adhoc** — universal, ad-hoc signed (not notarized); after download run"
  echo '  `xattr -dr com.apple.quarantine CopyParty.app` to launch.'
} >> "$NOTES"

log "Artifacts collected in $OUT"
ls -lh "$OUT"
echo
echo "Release notes ($NOTES):"
echo "------------------------------------------------------------------"
cat "$NOTES"
echo "------------------------------------------------------------------"

# ── Publish ──────────────────────────────────────────────────────────────────
ASSETS=("$OUT"/CopyParty-*.dmg "$OUT"/CopyParty-*.zip)
if [[ "$PUBLISH" == "1" ]]; then
  log "Publishing GitHub release $TAG"
  gh release create "$TAG" "${ASSETS[@]}" \
    --title "CopyParty $VERSION" \
    --notes-file "$NOTES"
  echo "Published: $(gh release view "$TAG" --json url -q .url 2>/dev/null || echo "$TAG")"
else
  log "DRY RUN — set PUBLISH=1 to create the release. Would run:"
  echo "  gh release create \"$TAG\" \\"
  for a in "${ASSETS[@]}"; do echo "    \"$a\" \\"; done
  echo "    --title \"CopyParty $VERSION\" --notes-file \"$NOTES\""
fi
