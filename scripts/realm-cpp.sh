#!/bin/bash
set -euo pipefail

VERSION="2.2.0"
ARTIFACT_FLAVOR="shared"

for arg in "$@"; do
    case $arg in
        --version=*)         VERSION="${arg#*=}" ;;
        --artifact-flavor=*) ARTIFACT_FLAVOR="${arg#*=}" ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGES_DIR="$SCRIPT_DIR/../packages"
REALM_DIR="/tmp/realm-cpp-build/src"
REALM_INSTALL="/tmp/realm-cpp-build/install"

mkdir -p "$PACKAGES_DIR" "/tmp/realm-cpp-build"

if [ ! -e "$REALM_DIR" ]; then
    git clone https://github.com/mezleca/realm-cpp "$REALM_DIR"
fi

cd "$REALM_DIR"
git submodule update --init --recursive

cmake -S . -B build -G Ninja \
    -Wno-dev \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_STANDARD=17 \
    -DCMAKE_CXX_STANDARD_REQUIRED=ON \
    -DCMAKE_INSTALL_PREFIX="$REALM_INSTALL" \
    -DREALM_NO_TESTS=ON \
    -DREALM_CPP_NO_TESTS=ON \
    || exit 1

ninja -j 4 -C build
ninja -C build install

tar -czf "$PACKAGES_DIR/realm-cpp-$VERSION-x64-linux-clang-$ARTIFACT_FLAVOR.tar.gz" \
    -C "$REALM_INSTALL" .
