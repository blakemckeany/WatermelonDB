#!/usr/bin/env bash
# Fetch and build the SQLCipher Community Edition amalgamation
# (sqlite3.c + sqlite3.h) into native/sqlite-cipher-amalgamation/.
#
# Idempotent: if the destination files already exist and match the pinned
# version, this script is a no-op. Safe to call from `postinstall`.
#
# Build requirements:
#   - tclsh (any modern version)
#   - make
#   - a C compiler (only used to run the SQLite build's bootstrap tools)
#
# Override the pinned version with $SQLCIPHER_VERSION if you need a custom
# release. Verify integrity against the SHA-256 on the SQLCipher GitHub
# release page.

set -euo pipefail

SQLCIPHER_VERSION="${SQLCIPHER_VERSION:-4.6.1}"
SQLCIPHER_TARBALL_URL="https://github.com/sqlcipher/sqlcipher/archive/refs/tags/v${SQLCIPHER_VERSION}.tar.gz"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST_DIR="${ROOT_DIR}/native/sqlite-cipher-amalgamation"
PIN_FILE="${DEST_DIR}/.vendored-version"

if [[ -f "${DEST_DIR}/sqlite3.c" && -f "${DEST_DIR}/sqlite3.h" ]] \
   && [[ -f "${PIN_FILE}" ]] \
   && [[ "$(cat "${PIN_FILE}")" == "${SQLCIPHER_VERSION}" ]]; then
    echo "[vendor-sqlcipher] Already at v${SQLCIPHER_VERSION}, skipping."
    exit 0
fi

if ! command -v tclsh >/dev/null 2>&1; then
    echo "[vendor-sqlcipher] ERROR: tclsh is required to build the SQLCipher amalgamation."
    echo "  macOS:   brew install tcl-tk"
    echo "  Debian:  apt-get install tcl"
    echo "  Arch:    pacman -S tcl"
    exit 1
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

echo "[vendor-sqlcipher] Fetching SQLCipher v${SQLCIPHER_VERSION}..."
curl -fsSL "${SQLCIPHER_TARBALL_URL}" -o "${WORK_DIR}/sqlcipher.tar.gz"
tar -xzf "${WORK_DIR}/sqlcipher.tar.gz" -C "${WORK_DIR}"

SRC_DIR="${WORK_DIR}/sqlcipher-${SQLCIPHER_VERSION}"
cd "${SRC_DIR}"

echo "[vendor-sqlcipher] Configuring (codec=on, temp_store=memory)..."
./configure \
    --enable-tempstore=yes \
    --disable-tcl \
    CFLAGS="-DSQLITE_HAS_CODEC -DSQLITE_TEMP_STORE=2 -DSQLCIPHER_CRYPTO_OPENSSL" \
    >/dev/null

echo "[vendor-sqlcipher] Building amalgamation..."
make sqlite3.c >/dev/null

mkdir -p "${DEST_DIR}"
cp sqlite3.c sqlite3.h "${DEST_DIR}/"
echo "${SQLCIPHER_VERSION}" >"${PIN_FILE}"

echo "[vendor-sqlcipher] Installed SQLCipher v${SQLCIPHER_VERSION} amalgamation to ${DEST_DIR}/"
