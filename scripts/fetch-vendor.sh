#!/usr/bin/env bash
#
# fetch-vendor.sh — download the embedded Python runtime + copyparty-sfx.py
#
# Produces:
#   Vendor/python/...            relocatable CPython (astral-sh/python-build-standalone)
#   Vendor/copyparty/copyparty-sfx.py
#   Vendor/manifest.json         pinned versions for reproducibility
#
# Vendor/ is gitignored (large); this script + manifest are the source of truth.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR="$REPO_ROOT/Vendor"
PY_DIR="$VENDOR/python"
CP_DIR="$VENDOR/copyparty"
PY_VERSION_PREFIX="${PY_VERSION_PREFIX:-3.12.}"     # which CPython minor to pin
ARCH="aarch64-apple-darwin"                          # Apple Silicon
FLAVOR="install_only"                                # relocatable, no build deps

mkdir -p "$PY_DIR" "$CP_DIR"

log() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }

# ---------------------------------------------------------------------------
# 1. python-build-standalone
# ---------------------------------------------------------------------------
if [[ -x "$PY_DIR/bin/python3" ]]; then
  log "Python runtime already present, skipping ($($PY_DIR/bin/python3 --version 2>&1))"
  PY_ASSET_URL="(cached)"
else
  log "Resolving latest python-build-standalone release…"
  PBS_API="https://api.github.com/repos/astral-sh/python-build-standalone/releases/latest"
  PBS_JSON="$(curl -fsSL "$PBS_API")"

  # Pick the newest matching asset: cpython-3.12.*-aarch64-apple-darwin-install_only.tar.gz
  PY_ASSET_URL="$(printf '%s' "$PBS_JSON" \
    | grep -oE '"browser_download_url": *"[^"]*"' \
    | sed -E 's/.*"(https[^"]*)"/\1/' \
    | grep "cpython-${PY_VERSION_PREFIX}" \
    | grep "${ARCH}-${FLAVOR}.tar.gz" \
    | grep -v 'sha256' \
    | sort -V | tail -n1)"

  if [[ -z "$PY_ASSET_URL" ]]; then
    echo "ERROR: could not find a cpython-${PY_VERSION_PREFIX}* ${ARCH}-${FLAVOR} asset" >&2
    exit 1
  fi

  log "Downloading $PY_ASSET_URL"
  TARBALL="$VENDOR/python.tar.gz"
  curl -fL --retry 3 -o "$TARBALL" "$PY_ASSET_URL"

  log "Extracting Python runtime…"
  rm -rf "$PY_DIR"
  mkdir -p "$PY_DIR"
  # install_only tarballs extract to a top-level "python/" dir
  tar -xzf "$TARBALL" -C "$VENDOR"
  rm -f "$TARBALL"
  log "Python runtime: $($PY_DIR/bin/python3 --version 2>&1)"
fi

# ---------------------------------------------------------------------------
# 1b. optional copyparty dependencies (make it fully-featured)
#   paramiko    -> SFTP server
#   Pillow      -> image thumbnails
#   mutagen     -> fast audio/media tag indexing
#   impacket    -> SMB server
#   argon2-cffi -> argon2 password hashing
# These are installed into the bundled interpreter's site-packages, so copyparty
# (which imports them at runtime if present) picks them up automatically.
# NOTE: video thumbnails / transcoding additionally need an ffmpeg binary, which
# is not bundled here.
# ---------------------------------------------------------------------------
PY_BIN="$PY_DIR/bin/python3"
PIP_PACKAGES=(paramiko Pillow mutagen impacket argon2-cffi)
log "Installing optional copyparty dependencies into the bundled Python…"
"$PY_BIN" -m pip install --upgrade --disable-pip-version-check \
  "${PIP_PACKAGES[@]}"

# ---------------------------------------------------------------------------
# 2. copyparty-sfx.py
# ---------------------------------------------------------------------------
log "Resolving latest copyparty release…"
CP_API="https://api.github.com/repos/9001/copyparty/releases/latest"
CP_JSON="$(curl -fsSL "$CP_API")"
CP_TAG="$(printf '%s' "$CP_JSON" | grep -oE '"tag_name": *"[^"]*"' | head -n1 | sed -E 's/.*"([^"]*)"$/\1/')"
CP_SFX_URL="https://github.com/9001/copyparty/releases/latest/download/copyparty-sfx.py"

log "Downloading copyparty-sfx.py ($CP_TAG)…"
curl -fL --retry 3 -o "$CP_DIR/copyparty-sfx.py" "$CP_SFX_URL"

# Capture authoritative version + help text straight from the binary.
PY_BIN="$PY_DIR/bin/python3"
CP_VERSION="$("$PY_BIN" "$CP_DIR/copyparty-sfx.py" --version 2>&1 | head -n1 || true)"
"$PY_BIN" "$CP_DIR/copyparty-sfx.py" --help > "$CP_DIR/copyparty-help.txt" 2>&1 || true
log "copyparty version: $CP_VERSION"

# ---------------------------------------------------------------------------
# 3. manifest
# ---------------------------------------------------------------------------
PY_FULL_VERSION="$("$PY_BIN" --version 2>&1 | awk '{print $2}')"
cat > "$VENDOR/manifest.json" <<JSON
{
  "python": {
    "version": "$PY_FULL_VERSION",
    "arch": "$ARCH",
    "flavor": "$FLAVOR",
    "asset_url": "$PY_ASSET_URL"
  },
  "copyparty": {
    "tag": "$CP_TAG",
    "version_line": "$CP_VERSION",
    "sfx_url": "$CP_SFX_URL"
  }
}
JSON

log "Done. Manifest:"
cat "$VENDOR/manifest.json"
