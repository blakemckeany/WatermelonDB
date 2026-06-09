#!/usr/bin/env bash
# Build a 16 KB page-aligned static libcrypto for Android into
# native/android-jsi/third_party/openssl/<abi>/.
#
# Why this exists:
#   This fork's SQLCipher codec needs OpenSSL's libcrypto. It previously came
#   from the Google NDK prefab `com.android.ndk.thirdparty:openssl:1.1.1q-beta-1`,
#   whose prebuilt libcrypto.so / libssl.so are only 4 KB page-aligned (built
#   2022, project abandoned — no 16 KB release exists). That fails Google
#   Play's 16 KB page size requirement, mandatory for new apps/updates
#   targeting Android 15+.
#
#   Instead, this script builds libcrypto from pinned OpenSSL LTS source with
#   NDK r27 and installs it as a *static* archive (libcrypto.a). The
#   android-jsi CMakeLists links it into libwatermelondb-jsi.so, which is
#   already linked with `-Wl,-z,max-page-size=16384`, so the crypto code is
#   folded into an already-16 KB-aligned library and no separate .so ships at
#   all. SQLCipher's codec only needs libcrypto; libssl (TLS) is dropped.
#
# Like the SQLCipher amalgamation, the built archives are gitignored but
# included in the dist tarball (see third_party/openssl/.npmignore), so
# consuming apps get prebuilt libs and need no NDK-at-install-time step.
#
# Idempotent: skips if all ABIs are already built at the pinned version.
# Skips gracefully (exit 0) when no Android NDK is available — e.g. JS-only
# CI or iOS-only dev machines. If the Android build actually needs the libs
# and they're absent, CMakeLists.txt fails loudly at that point.
#
# Build requirements:
#   - Android NDK r27+ (set ANDROID_NDK_HOME, or have $ANDROID_HOME/ndk/27.*)
#   - perl, make, curl, sha256sum/shasum

set -euo pipefail

# --- Pinned source (verify the SHA-256 before trusting a new version) --------
OPENSSL_VERSION="${OPENSSL_VERSION:-3.5.6}"   # LTS line, supported through 2030
OPENSSL_SHA256="deae7c80cba99c4b4f940ecadb3c3338b13cb77418409238e57d7f31f2a3b736"

ABIS=(arm64-v8a armeabi-v7a x86 x86_64)
ANDROID_API="${OPENSSL_ANDROID_API:-24}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST_ROOT="${ROOT_DIR}/native/android-jsi/third_party/openssl"
STAMP="${DEST_ROOT}/.openssl-version"

log()  { printf '\033[36m[vendor-openssl]\033[0m %s\n' "$*"; }
err()  { printf '\033[31m[vendor-openssl] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }
skip() { printf '\033[33m[vendor-openssl] SKIP:\033[0m %s\n' "$*" >&2; exit 0; }

# --- Idempotency: skip if all ABIs already built for this exact version ------
if [ -f "$STAMP" ] && [ "$(cat "$STAMP")" = "$OPENSSL_VERSION" ]; then
  all_present=1
  for abi in "${ABIS[@]}"; do
    [ -f "$DEST_ROOT/$abi/lib/libcrypto.a" ] || all_present=0
  done
  if [ "$all_present" = "1" ]; then
    log "OpenSSL $OPENSSL_VERSION libcrypto.a already vendored for all ABIs — skipping."
    exit 0
  fi
fi

# --- Locate NDK r27 -----------------------------------------------------------
NDK="${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-${ANDROID_NDK_LATEST_HOME:-}}}"
if [ -z "$NDK" ] && [ -n "${ANDROID_HOME:-}" ]; then
  NDK="$(ls -d "$ANDROID_HOME"/ndk/27.* 2>/dev/null | sort -V | tail -n1 || true)"
fi
if [ -z "$NDK" ] && [ -n "${ANDROID_SDK_ROOT:-}" ]; then
  NDK="$(ls -d "$ANDROID_SDK_ROOT"/ndk/27.* 2>/dev/null | sort -V | tail -n1 || true)"
fi
[ -n "$NDK" ] && [ -d "$NDK" ] || skip "Android NDK not found — skipping (set ANDROID_NDK_HOME to build the vendored libcrypto)."
case "$(basename "$NDK")" in
  2[7-9].*|[3-9][0-9].*) : ;;
  *) log "WARNING: NDK at $NDK is older than r27. r27+ is required for default 16 KB alignment." ;;
esac

HOST_TAG="linux-x86_64"
[ "$(uname -s)" = "Darwin" ] && HOST_TAG="darwin-x86_64"
TOOLCHAIN="$NDK/toolchains/llvm/prebuilt/$HOST_TAG"
[ -d "$TOOLCHAIN" ] || skip "NDK toolchain not found at $TOOLCHAIN — skipping."

command -v perl >/dev/null 2>&1 || skip "perl not available — skipping."
command -v curl >/dev/null 2>&1 || skip "curl not available — skipping."
command -v sha256sum >/dev/null 2>&1 || command -v shasum >/dev/null 2>&1 \
  || skip "Need sha256sum or shasum to verify the download — skipping."

# --- Fetch + verify source ----------------------------------------------------
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
TARBALL="$WORK/openssl-$OPENSSL_VERSION.tar.gz"
URL="https://github.com/openssl/openssl/releases/download/openssl-$OPENSSL_VERSION/openssl-$OPENSSL_VERSION.tar.gz"

log "Downloading $URL"
curl -fsSL "$URL" -o "$TARBALL"

log "Verifying SHA-256"
if command -v sha256sum >/dev/null 2>&1; then
  echo "$OPENSSL_SHA256  $TARBALL" | sha256sum -c - >/dev/null \
    || err "SHA-256 mismatch — refusing to build. Expected $OPENSSL_SHA256"
else
  got="$(shasum -a 256 "$TARBALL" | awk '{print $1}')"
  [ "$got" = "$OPENSSL_SHA256" ] || err "SHA-256 mismatch (got $got, expected $OPENSSL_SHA256)"
fi

tar xzf "$TARBALL" -C "$WORK"
SRC="$WORK/openssl-$OPENSSL_VERSION"

export ANDROID_NDK_ROOT="$NDK"
export PATH="$TOOLCHAIN/bin:$PATH"

abi_to_target() {
  case "$1" in
    arm64-v8a)   echo android-arm64 ;;
    armeabi-v7a) echo android-arm ;;
    x86)         echo android-x86 ;;
    x86_64)      echo android-x86_64 ;;
    *) err "Unknown ABI: $1" ;;
  esac
}

JOBS="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)"

for abi in "${ABIS[@]}"; do
  target="$(abi_to_target "$abi")"
  dest="$DEST_ROOT/$abi"
  log "Building OpenSSL $OPENSSL_VERSION libcrypto for $abi ($target, API $ANDROID_API)"

  builddir="$WORK/build-$abi"
  cp -a "$SRC" "$builddir"
  (
    cd "$builddir"
    # no-shared          -> static archives only (no .so to misalign)
    # no-tests/apps/docs -> faster build, smaller footprint
    # no-engine/legacy   -> not needed by SQLCipher's codec
    # max-page-size flag -> defensive; static link makes the host .so alignment
    #                       authoritative, but keep parity with the NDK default.
    ./Configure "$target" \
      -D__ANDROID_API__="$ANDROID_API" \
      no-shared no-tests no-apps no-docs no-engine no-legacy \
      -Wl,-z,max-page-size=16384 \
      --prefix="$dest" --openssldir="$dest" >/dev/null
    make -s -j"$JOBS" build_libs >/dev/null
    rm -rf "$dest"
    make -s install_dev >/dev/null
    # SQLCipher needs only libcrypto; drop libssl + non-essential install output.
    rm -f "$dest/lib/libssl.a" "$dest/lib/pkgconfig/libssl.pc" 2>/dev/null || true
  )
  [ -f "$dest/lib/libcrypto.a" ] || err "Build produced no libcrypto.a for $abi"
done

echo "$OPENSSL_VERSION" > "$STAMP"
log "✅ libcrypto.a (16 KB-ready, static) vendored for: ${ABIS[*]}"
log "   -> $DEST_ROOT"
