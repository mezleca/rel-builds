#!/bin/bash

# TOFIX: actually use the version
# TODO: custom toolchain (maybe)

VERSION="2.2.0"
PLATFORM="linux"

cd_or_create() {
    if [ ! -d "$1" ]; then
        mkdir -p "$1"
    fi
    cd "$1"
}

for arg in "$@"; do
    case $arg in
        --platform=*)
            PLATFORM="${arg#*=}"
            ;;
        --version=*)
            VERSION="${arg#*=}"
            ;;
    esac
done

# configure
CUR=$(pwd)

REALM_DIR="$CUR/realm-cpp"
REALM_BUILD_DIR="$REALM_DIR/build"
REALM_INSTALL_DIR="$CUR/install"

CMAKE_EXTRA_FLAGS=""

if [[ "$PLATFORM" == "windows" ]]; then
    CMAKE_EXTRA_FLAGS="-DOPENSSL_ROOT_DIR=/mingw64"
fi

if [[ "$PLATFORM" == "windows" ]]; then
    CXX_COMPILER="x86_64-w64-mingw32-g++"
    C_COMPILER="x86_64-w64-mingw32-gcc"
    TAR_TARGET="$CUR/realm-cpp-$VERSION-x64-windows-mingw-shared.tar.gz"
else
    CXX_COMPILER="clang++"
    C_COMPILER="clang"
    TAR_TARGET="$CUR/realm-cpp-$VERSION-x64-linux-clang-shared.tar.gz"
fi

# clone / initialize forked repo
if [ ! -e "$REALM_DIR" ]; then
    git clone https://github.com/mezleca/realm-cpp
fi

cd realm-cpp && git submodule update --init --recursive

# build
cd "$REALM_DIR" && cmake -S . -B build -G Ninja \
    -Wno-deprecated-literal-operator \
    -Wno-unused-private-field \
    -Wno-dev \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_COMPILER="$CXX_COMPILER" \
    -DCMAKE_C_COMPILER="$C_COMPILER" \
    -DCMAKE_CXX_STANDARD_REQUIRED=ON \
    -DCMAKE_CXX_STANDARD=17 \
    -DCMAKE_INSTALL_PREFIX="$REALM_INSTALL_DIR" \
    -DREALM_NO_TESTS=ON \
    -DREALM_CPP_NO_TESTS=ON \
    $CMAKE_EXTRA_FLAGS || exit 1
 
cd_or_create "$REALM_BUILD_DIR" && ninja -j 4 && ninja install
cd_or_create "$CUR" && tar -czf "$TAR_TARGET" -C "$REALM_INSTALL_DIR" .
