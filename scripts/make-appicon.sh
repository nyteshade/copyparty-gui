#!/usr/bin/env bash
# make-appicon.sh — build AppIcon.appiconset from the canonical source icon.
#
# Preferred source is a proper multi-resolution .icns (true masters at every
# size, including a real 1024px); falls back to resizing a single PNG.
#
# Usage: make-appicon.sh [source.icns | source.png]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${1:-$REPO_ROOT/Resources/Icon/A-Side.icns}"
OUT="$REPO_ROOT/Resources/Assets.xcassets/AppIcon.appiconset"

mkdir -p "$OUT"
echo "==> Generating AppIcon from $SRC"

write_contents() {
  cat > "$OUT/Contents.json" <<'JSON'
{
  "images" : [
    { "size" : "16x16",   "idiom" : "mac", "filename" : "icon_16.png",     "scale" : "1x" },
    { "size" : "16x16",   "idiom" : "mac", "filename" : "icon_16@2x.png",  "scale" : "2x" },
    { "size" : "32x32",   "idiom" : "mac", "filename" : "icon_32.png",     "scale" : "1x" },
    { "size" : "32x32",   "idiom" : "mac", "filename" : "icon_32@2x.png",  "scale" : "2x" },
    { "size" : "128x128", "idiom" : "mac", "filename" : "icon_128.png",    "scale" : "1x" },
    { "size" : "128x128", "idiom" : "mac", "filename" : "icon_128@2x.png", "scale" : "2x" },
    { "size" : "256x256", "idiom" : "mac", "filename" : "icon_256.png",    "scale" : "1x" },
    { "size" : "256x256", "idiom" : "mac", "filename" : "icon_256@2x.png", "scale" : "2x" },
    { "size" : "512x512", "idiom" : "mac", "filename" : "icon_512.png",    "scale" : "1x" },
    { "size" : "512x512", "idiom" : "mac", "filename" : "icon_512@2x.png", "scale" : "2x" }
  ],
  "info" : { "version" : 1, "author" : "xcode" }
}
JSON
}

if [[ "$SRC" == *.icns ]]; then
  # Expand the .icns and map its masters onto the asset-catalog filenames.
  TMP="$(mktemp -d)/icon.iconset"
  iconutil -c iconset "$SRC" -o "$TMP"
  cp "$TMP/icon_16x16.png"      "$OUT/icon_16.png"
  cp "$TMP/icon_16x16@2x.png"   "$OUT/icon_16@2x.png"
  cp "$TMP/icon_32x32.png"      "$OUT/icon_32.png"
  cp "$TMP/icon_32x32@2x.png"   "$OUT/icon_32@2x.png"
  cp "$TMP/icon_128x128.png"    "$OUT/icon_128.png"
  cp "$TMP/icon_128x128@2x.png" "$OUT/icon_128@2x.png"
  cp "$TMP/icon_256x256.png"    "$OUT/icon_256.png"
  cp "$TMP/icon_256x256@2x.png" "$OUT/icon_256@2x.png"
  cp "$TMP/icon_512x512.png"    "$OUT/icon_512.png"
  cp "$TMP/icon_512x512@2x.png" "$OUT/icon_512@2x.png"
  rm -rf "$(dirname "$TMP")"
else
  gen() { sips -s format png -z "$1" "$1" "$SRC" --out "$OUT/$2" >/dev/null; }
  gen 16 icon_16.png;   gen 32 icon_16@2x.png
  gen 32 icon_32.png;   gen 64 icon_32@2x.png
  gen 128 icon_128.png; gen 256 icon_128@2x.png
  gen 256 icon_256.png; gen 512 icon_256@2x.png
  gen 512 icon_512.png; gen 1024 icon_512@2x.png
fi

write_contents
echo "==> AppIcon.appiconset ready"
