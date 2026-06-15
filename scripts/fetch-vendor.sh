#!/usr/bin/env bash
#
# fetch-vendor.sh — download/assemble the embedded Python runtime + copyparty-sfx.py
#
# Architecture is selected with VENDOR_ARCH:
#   VENDOR_ARCH=arm64      (default) Apple Silicon only
#   VENDOR_ARCH=x86_64     Intel only
#   VENDOR_ARCH=universal  fat arm64+x86_64 — fetches BOTH python-build-standalone
#                          builds and lipo-merges every Mach-O. x86_64 deps are
#                          pip-installed under Rosetta (arch -x86_64).
#
# Produces:
#   Vendor/python/...            relocatable CPython (astral-sh/python-build-standalone)
#   Vendor/copyparty/copyparty-sfx.py
#   Vendor/manifest.json         pinned versions + arch for reproducibility
#
# Vendor/ is gitignored (large); this script + manifest are the source of truth.
# Set FORCE=1 to ignore any cached runtime and rebuild from scratch.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR="$REPO_ROOT/Vendor"
PY_DIR="$VENDOR/python"
CP_DIR="$VENDOR/copyparty"
PY_VERSION_PREFIX="${PY_VERSION_PREFIX:-3.12.}"     # which CPython minor to pin
FLAVOR="install_only"                                # relocatable, no build deps
VENDOR_ARCH="${VENDOR_ARCH:-arm64}"
FORCE="${FORCE:-0}"
# cryptography>=49 dropped its Intel-macOS wheel (arm64-only), which would force a
# doomed Rust/OpenSSL source build under Rosetta for the x86_64 leg of a universal
# build. Cap it at the last version that ships a macosx universal2 wheel.
PIP_PACKAGES=(paramiko Pillow mutagen impacket argon2-cffi "cryptography<49")
# Native-extension packages: force prebuilt wheels (never source-build) on the
# x86_64/Rosetta install so a missing wheel fails fast instead of compiling.
NATIVE_BINARY="cryptography,cffi,bcrypt,pynacl,pycryptodome,pillow,argon2-cffi-bindings"

mkdir -p "$VENDOR" "$CP_DIR"

# Logs go to stderr so functions can "return" strings on stdout.
log() { printf '\033[1;36m==>\033[0m %s\n' "$*" >&2; }

pbs_triple() {
  case "$1" in
    arm64)  echo "aarch64-apple-darwin" ;;
    x86_64) echo "x86_64-apple-darwin" ;;
    *) echo "ERROR: unknown arch '$1'" >&2; return 1 ;;
  esac
}

# Resolve the newest matching install_only asset URL for a PBS triple.
resolve_asset_url() {
  local triple="$1" json
  json="$(curl -fsSL https://api.github.com/repos/astral-sh/python-build-standalone/releases/latest)"
  printf '%s' "$json" \
    | grep -oE '"browser_download_url": *"[^"]*"' \
    | sed -E 's/.*"(https[^"]*)"/\1/' \
    | grep "cpython-${PY_VERSION_PREFIX}" \
    | grep "${triple}-${FLAVOR}.tar.gz" \
    | grep -v 'sha256' \
    | sort -V | tail -n1
}

# Download + extract one arch into a destination dir (which becomes the python root).
# Echoes the asset URL on stdout.
fetch_arch() {
  local arch="$1" dest="$2" triple url tarball tmpx
  triple="$(pbs_triple "$arch")"
  url="$(resolve_asset_url "$triple")"
  [[ -n "$url" ]] || { echo "ERROR: no cpython-${PY_VERSION_PREFIX}* ${triple}-${FLAVOR} asset" >&2; return 1; }
  log "[$arch] downloading $url"
  tarball="$(mktemp -t pbs-XXXXXX)"
  curl -fL --retry 3 -o "$tarball" "$url"
  tmpx="$(mktemp -d)"
  tar -xzf "$tarball" -C "$tmpx"        # install_only extracts to top-level python/
  rm -rf "$dest"; mkdir -p "$dest"
  mv "$tmpx/python/"* "$dest/"
  rm -rf "$tmpx" "$tarball"
  log "[$arch] $("$dest/bin/python3" --version 2>&1)"
  echo "$url"
}

# Install the optional copyparty deps into an interpreter. x86_64 runs via Rosetta.
pip_install() {
  local arch="$1" py="$2" reqs="${3:-}"
  local runner=("$py")
  if [[ "$arch" == "x86_64" && "$(uname -m)" == "arm64" ]]; then
    runner=(arch -x86_64 "$py")
  fi
  if [[ -n "$reqs" ]]; then
    log "[$arch] installing pinned deps from $(basename "$reqs")"
    local extra=()
    [[ "$arch" == "x86_64" ]] && extra=(--only-binary "$NATIVE_BINARY")
    "${runner[@]}" -m pip install --disable-pip-version-check "${extra[@]}" -r "$reqs"
  else
    log "[$arch] installing deps: ${PIP_PACKAGES[*]}"
    "${runner[@]}" -m pip install --upgrade --disable-pip-version-check "${PIP_PACKAGES[@]}"
  fi
}

# lipo-merge two thin runtimes ($1 arm64, $2 x86_64) into a fat tree ($3).
# Many wheels already ship macosx universal2 (.so already fat); those are left
# as-is. Only genuinely thin (arm64-only) binaries are merged with their x86 twin.
merge_universal() {
  local A="$1" X="$2" O="$3" rel archs count=0 already=0 missing=0
  log "merging universal runtime (lipo)…"
  rm -rf "$O"; mkdir -p "$O"
  rsync -a "$A/" "$O/"        # pure-python + data are identical between arches
  while IFS= read -r rel; do
    archs="$(lipo -archs "$O/$rel" 2>/dev/null || echo)"
    if grep -q x86_64 <<<"$archs"; then
      already=$((already + 1)); continue              # universal2 wheel, already fat
    fi
    if [[ -f "$X/$rel" ]] && lipo -create "$O/$rel" "$X/$rel" -output "$O/$rel.fat" 2>/dev/null; then
      mv "$O/$rel.fat" "$O/$rel"; count=$((count + 1))
    else
      rm -f "$O/$rel.fat"
      log "  warn: could not add x86_64 to $rel (leaving arm64-only)"
      missing=$((missing + 1))
    fi
  # Candidate Mach-O: every .so/.dylib, plus native (non-.py) executables in bin/.
  # Listed relative to $O so paths stay clean (no `file` fat-arch line splitting).
  done < <(cd "$O" && {
      find . -type f \( -name '*.so' -o -name '*.dylib' \)
      find ./bin -type f ! -name '*.py' -exec sh -c 'file -b "$1" | head -1 | grep -q Mach-O' _ {} \; -print
    } | sed 's|^\./||' | sort -u)
  log "  merged $count thin binaries, $already already-universal, $missing unmatched"
}

# Is the current Vendor/python already the requested arch (with deps + sfx)?
have_runtime() {
  local want="$1" bin="$PY_DIR/bin/python3.12" archs
  [[ "$FORCE" != "1" ]] || return 1
  [[ -x "$bin" ]] || return 1
  [[ -d "$PY_DIR/lib/python3.12/site-packages/paramiko" ]] || return 1
  [[ -f "$CP_DIR/copyparty-sfx.py" ]] || return 1
  archs="$(lipo -archs "$bin" 2>/dev/null || echo)"
  case "$want" in
    arm64)     [[ "$archs" == "arm64" ]] ;;
    x86_64)    [[ "$archs" == "x86_64" ]] ;;
    universal) grep -q arm64 <<<"$archs" && grep -q x86_64 <<<"$archs" ;;
  esac
}

# ---------------------------------------------------------------------------
# 1. python runtime
# ---------------------------------------------------------------------------
PY_ASSET_URL=""
PY_ASSET_URL_X86=""
if have_runtime "$VENDOR_ARCH"; then
  log "Python runtime already present for '$VENDOR_ARCH' ($(lipo -archs "$PY_DIR/bin/python3.12")), skipping"
  PY_ASSET_URL="(cached)"
else
  case "$VENDOR_ARCH" in
    arm64|x86_64)
      PY_ASSET_URL="$(fetch_arch "$VENDOR_ARCH" "$PY_DIR")"
      pip_install "$VENDOR_ARCH" "$PY_DIR/bin/python3"
      ;;
    universal)
      ARM_DIR="$VENDOR/.python-arm64"
      X86_DIR="$VENDOR/.python-x86_64"
      REQS="$VENDOR/.reqs.txt"
      PY_ASSET_URL="$(fetch_arch arm64 "$ARM_DIR")"
      PY_ASSET_URL_X86="$(fetch_arch x86_64 "$X86_DIR")"
      # Install arm64 deps, freeze the exact resolved set, install the SAME
      # versions into x86_64 so both trees match file-for-file before lipo.
      pip_install arm64 "$ARM_DIR/bin/python3"
      "$ARM_DIR/bin/python3" -m pip freeze --disable-pip-version-check > "$REQS"
      pip_install x86_64 "$X86_DIR/bin/python3" "$REQS"
      merge_universal "$ARM_DIR" "$X86_DIR" "$PY_DIR"
      rm -rf "$ARM_DIR" "$X86_DIR" "$REQS"
      log "universal python: $(lipo -archs "$PY_DIR/bin/python3.12")"
      ;;
    *)
      echo "ERROR: VENDOR_ARCH must be arm64, x86_64, or universal" >&2; exit 1 ;;
  esac
fi

# ---------------------------------------------------------------------------
# 2. copyparty-sfx.py  (architecture-independent)
# ---------------------------------------------------------------------------
PY_BIN="$PY_DIR/bin/python3"
log "Resolving latest copyparty release…"
CP_JSON="$(curl -fsSL https://api.github.com/repos/9001/copyparty/releases/latest)"
CP_TAG="$(printf '%s' "$CP_JSON" | grep -oE '"tag_name": *"[^"]*"' | head -n1 | sed -E 's/.*"([^"]*)"$/\1/')"
CP_SFX_URL="https://github.com/9001/copyparty/releases/latest/download/copyparty-sfx.py"
if [[ ! -f "$CP_DIR/copyparty-sfx.py" || "$FORCE" == "1" ]]; then
  log "Downloading copyparty-sfx.py ($CP_TAG)…"
  curl -fL --retry 3 -o "$CP_DIR/copyparty-sfx.py" "$CP_SFX_URL"
fi
CP_VERSION="$("$PY_BIN" "$CP_DIR/copyparty-sfx.py" --version 2>&1 | grep -oE 'copyparty [0-9][^ ]*' | head -n1 || true)"
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
    "arch": "$VENDOR_ARCH",
    "flavor": "$FLAVOR",
    "asset_url": "$PY_ASSET_URL",
    "asset_url_x86_64": "$PY_ASSET_URL_X86"
  },
  "copyparty": {
    "tag": "$CP_TAG",
    "version_line": "$CP_VERSION",
    "sfx_url": "$CP_SFX_URL"
  }
}
JSON

log "Done ($VENDOR_ARCH). Manifest:"
cat "$VENDOR/manifest.json" >&2
