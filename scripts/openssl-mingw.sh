#!/bin/bash

set -euo pipefail

VERSION="3.3.1"

for arg in "$@"; do
    case $arg in --version=*) VERSION="${arg#*=}" ;; esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGES_DIR="$SCRIPT_DIR/../packages"
TMP_SRC="/tmp/openssl-${VERSION}"
TMP_INSTALL="/tmp/openssl-install"

mkdir -p "$PACKAGES_DIR"

curl -L -o /tmp/openssl.tar.gz "https://www.openssl.org/source/openssl-${VERSION}.tar.gz"
tar -xzf /tmp/openssl.tar.gz -C /tmp
cd "$TMP_SRC"

./Configure mingw64 \
    --cross-compile-prefix=x86_64-w64-mingw32- \
    no-shared no-tests \
    --prefix="$TMP_INSTALL" \
    -D_UCRT

make -j"$(nproc)"
make install_sw

tar -czf "$PACKAGES_DIR/openssl-${VERSION}-x64-windows-mingw-static.tar.gz" \
    -C "$TMP_INSTALL" .
