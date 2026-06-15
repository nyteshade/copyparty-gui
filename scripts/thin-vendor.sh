#!/usr/bin/env bash
#
# thin-vendor.sh <arm64|x86_64> — lipo-thin every fat Mach-O in Vendor/python
# down to a single architecture, in place. Lets the release pipeline derive an
# arm64-only runtime from a universal one without re-downloading anything.
set -euo pipefail

ARCH="${1:?usage: thin-vendor.sh <arm64|x86_64>}"
case "$ARCH" in arm64|x86_64) ;; *) echo "ERROR: arch must be arm64 or x86_64" >&2; exit 1 ;; esac

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PY_DIR="$REPO_ROOT/Vendor/python"
[[ -d "$PY_DIR" ]] || { echo "ERROR: $PY_DIR not found (run fetch-vendor.sh first)" >&2; exit 1; }

log() { printf '\033[1;36m==>\033[0m %s\n' "$*" >&2; }

log "thinning Vendor/python Mach-O binaries to ${ARCH}…"
count=0
while IFS= read -r f; do
  archs="$(lipo -archs "$f" 2>/dev/null || echo)"
  # Only act on fat binaries that contain the target arch.
  if grep -qw "$ARCH" <<<"$archs" && [[ "$archs" != "$ARCH" ]]; then
    if lipo -thin "$ARCH" "$f" -output "$f.thin" 2>/dev/null; then
      mv "$f.thin" "$f"; count=$((count + 1))
    else
      rm -f "$f.thin"
    fi
  fi
done < <(find "$PY_DIR" -type f -print0 | xargs -0 file | grep "Mach-O" | cut -d: -f1)
log "thinned $count Mach-O files to $ARCH"

# Keep the manifest honest about what's on disk now.
MANIFEST="$REPO_ROOT/Vendor/manifest.json"
if [[ -f "$MANIFEST" ]]; then
  tmp="$(mktemp)"
  sed -E "s/(\"arch\": *\")[^\"]*(\")/\1$ARCH\2/" "$MANIFEST" > "$tmp" && mv "$tmp" "$MANIFEST"
fi
log "done — Vendor/python is now $(lipo -archs "$PY_DIR/bin/python3.12")"
