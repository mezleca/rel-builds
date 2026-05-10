param(
    [string]$Version = "2.2.0",
    [string]$ArtifactFlavor = "static",
    [ValidateSet("mingw", "msvc")]
    [string]$Toolchain = "mingw"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$OrigDir      = $PWD.Path
$PackagesDir  = "$PSScriptRoot\..\packages"
$TmpBase      = "$env:TEMP\realm-cpp-build"
$RealmDir     = "$TmpBase\src"
$RealmBuild   = "$RealmDir\build"
$RealmInstall = "$TmpBase\install"

New-Item -ItemType Directory -Force -Path $PackagesDir | Out-Null
New-Item -ItemType Directory -Force -Path $TmpBase | Out-Null

if ($Toolchain -eq "mingw") {
    $env:PATH = "C:\msys64\mingw64\bin;$env:PATH"

    $TarTarget   = "$PackagesDir\realm-cpp-$Version-x64-windows-mingw-$ArtifactFlavor.tar.gz"
    $CxxCompiler = "x86_64-w64-mingw32-g++"
    $CCompiler   = "x86_64-w64-mingw32-gcc"

    $ExtraFlags = @(
        "-DREALM_USE_SYSTEM_OPENSSL=ON",
        "-DBUILD_SHARED_LIBS=OFF",
        "-DOPENSSL_ROOT_DIR=C:/msys64/mingw64",
        "-DOPENSSL_CRYPTO_LIBRARY=C:/msys64/mingw64/lib/libcrypto.a",
        "-DOPENSSL_SSL_LIBRARY=C:/msys64/mingw64/lib/libssl.a",
        "-DOPENSSL_INCLUDE_DIR=C:/msys64/mingw64/include",
        "-DZLIB_LIBRARY=C:/msys64/mingw64/lib/libz.a",
        "-DZLIB_LIBRARY_RELEASE=C:/msys64/mingw64/lib/libz.a",
        "-DZLIB_LIBRARY_DEBUG=C:/msys64/mingw64/lib/libz.a",
        "-DZLIB_INCLUDE_DIR=C:/msys64/mingw64/include"
    )

} elseif ($Toolchain -eq "msvc") {
    $TarTarget   = "$PackagesDir\realm-cpp-$Version-x64-windows-msvc-$ArtifactFlavor.tar.gz"
    $CxxCompiler = "cl"
    $CCompiler   = "cl"

    $VcVarsCandidates = @(
        "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvarsall.bat",
        "C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvarsall.bat",
        "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat"
    )

    $VcVars = $VcVarsCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $VcVars) {
        Write-Error "vcvarsall.bat not found."
        exit 1
    }

    $EnvDump = cmd /c "`"$VcVars`" x64 > nul 2>&1 && set"

    foreach ($line in $EnvDump) {
        if ($line -match "^([^=]+)=(.*)$") {
            [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2], "Process")
        }
    }

    $ExtraFlags = @(
        "-DREALM_USE_SYSTEM_OPENSSL=ON",
        "-DBUILD_SHARED_LIBS=OFF"
    )
}

try {

if (-not (Test-Path $RealmDir)) {
    git clone https://github.com/mezleca/realm-cpp $RealmDir
}

Set-Location $RealmDir
git submodule update --init --recursive

$CMakeArgs = @(
    "-S", $RealmDir,
    "-B", $RealmBuild,
    "-G", "Ninja",
    "-Wno-dev",
    "-DCMAKE_BUILD_TYPE=Release",
    "-DCMAKE_CXX_COMPILER=$CxxCompiler",
    "-DCMAKE_C_COMPILER=$CCompiler",
    "-DCMAKE_CXX_STANDARD=17",
    "-DCMAKE_CXX_STANDARD_REQUIRED=ON",
    "-DCMAKE_INSTALL_PREFIX=$RealmInstall",
    "-DREALM_NO_TESTS=ON",
    "-DREALM_CPP_NO_TESTS=ON"
) + $ExtraFlags

cmake @CMakeArgs
if ($LASTEXITCODE -ne 0) { exit 1 }

ninja -j 4 -C $RealmBuild
if ($LASTEXITCODE -ne 0) { exit 1 }

ninja -C $RealmBuild install
if ($LASTEXITCODE -ne 0) { exit 1 }

tar -czf $TarTarget -C $RealmInstall .
} finally {
    Set-Location $OrigDir
}
