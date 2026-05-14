#!/bin/bash
set -euo pipefail

VERSION="2.2.0"
ARTIFACT_FLAVOR="shared"
BUILD_VARIANT="linux-clang"

for arg in "$@"; do
    case $arg in
        --version=*)         VERSION="${arg#*=}" ;;
        --artifact-flavor=*) ARTIFACT_FLAVOR="${arg#*=}" ;;
        --build-variant=*)   BUILD_VARIANT="${arg#*=}" ;;
    esac
done

case "$BUILD_VARIANT" in
    linux-clang)
        CMAKE_PIC_FLAGS=()
        CXX_PIC_FLAGS=()
        C_PIC_FLAGS=()
        ;;
    linux-clang-fpic)
        CMAKE_PIC_FLAGS=("-DCMAKE_POSITION_INDEPENDENT_CODE=ON")
        CXX_PIC_FLAGS=("-DCMAKE_CXX_FLAGS_RELEASE=-O3 -DNDEBUG -fPIC")
        C_PIC_FLAGS=("-DCMAKE_C_FLAGS_RELEASE=-O3 -DNDEBUG -fPIC")
        ;;
    *)
        echo "invalid build variant: $BUILD_VARIANT" >&2
        exit 1
        ;;
esac

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGES_DIR="$SCRIPT_DIR/../packages"
REALM_DIR="/tmp/realm-cpp-build/src"
REALM_BUILD="/tmp/realm-cpp-build/build-$BUILD_VARIANT"
REALM_INSTALL="/tmp/realm-cpp-build/install-$BUILD_VARIANT"

mkdir -p "$PACKAGES_DIR" "/tmp/realm-cpp-build"

if [ ! -e "$REALM_DIR" ]; then
    git clone https://github.com/mezleca/realm-cpp "$REALM_DIR"
fi

cd "$REALM_DIR"
git submodule update --init --recursive

rm -rf "$REALM_BUILD" "$REALM_INSTALL"

cmake -S . -B "$REALM_BUILD" -G Ninja \
    -Wno-dev \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_STANDARD=17 \
    -DCMAKE_CXX_STANDARD_REQUIRED=ON \
    -DCMAKE_INSTALL_PREFIX="$REALM_INSTALL" \
    -DREALM_NO_TESTS=ON \
    -DREALM_CPP_NO_TESTS=ON \
    "${CMAKE_PIC_FLAGS[@]}" \
    "${CXX_PIC_FLAGS[@]}" \
    "${C_PIC_FLAGS[@]}" \
    || exit 1

ninja -j 4 -C "$REALM_BUILD"
ninja -C "$REALM_BUILD" install

tar -czf "$PACKAGES_DIR/realm-cpp-$VERSION-x64-$BUILD_VARIANT-$ARTIFACT_FLAVOR.tar.gz" \
    -C "$REALM_INSTALL" .
