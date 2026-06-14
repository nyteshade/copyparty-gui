#!/usr/bin/env bash
# embed-vendor.sh — Xcode build phase: copy the vendored Python runtime and
# copyparty-sfx.py into the built .app's Resources, before code signing.
set -euo pipefail

: "${SRCROOT:?must run as an Xcode build phase}"
: "${TARGET_BUILD_DIR:?}"
: "${UNLOCALIZED_RESOURCES_FOLDER_PATH:?}"

VENDOR="$SRCROOT/Vendor"
DEST="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH"

# Make sure the vendor payload exists (fetch on a clean checkout / CI).
if [[ ! -x "$VENDOR/python/bin/python3" || ! -f "$VENDOR/copyparty/copyparty-sfx.py" ]]; then
  echo "note: Vendor payload missing — running fetch-vendor.sh"
  bash "$SRCROOT/scripts/fetch-vendor.sh"
fi

echo "note: embedding Python runtime + copyparty-sfx into $DEST"
mkdir -p "$DEST/python" "$DEST/copyparty"
# -a preserves symlinks/exec bits; --delete keeps the bundle in sync with Vendor.
rsync -a --delete "$VENDOR/python/" "$DEST/python/"
rsync -a "$VENDOR/copyparty/copyparty-sfx.py" "$DEST/copyparty/copyparty-sfx.py"
[[ -f "$VENDOR/manifest.json" ]] && rsync -a "$VENDOR/manifest.json" "$DEST/manifest.json"

# Ship the raw, unmasked .icns so the app can override the Dock icon at launch
# (defeating the macOS 26 squircle mask — see DockIcon.swift).
if [[ -f "$SRCROOT/Resources/Icon/A-Side.icns" ]]; then
  rsync -a "$SRCROOT/Resources/Icon/A-Side.icns" "$DEST/A-Side.icns"
fi

echo "note: embed-vendor complete"
