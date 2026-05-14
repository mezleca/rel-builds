param(
    [string]$Version = "1.52.1"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$PackagesDir = "$PSScriptRoot\..\packages"
$SrcDir      = "$env:TEMP\uv-src"
$InstallDir  = "$env:TEMP\uv-install"

New-Item -ItemType Directory -Force -Path $PackagesDir | Out-Null

$OrigDir = $PWD.Path

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

foreach ($tool in @("cl", "perl", "nasm", "nmake")) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Write-Error "'$tool' not found in PATH."
        exit 1
    }
}

try {
if (-not (Test-Path $SrcDir)) {
    $TarUrl  = "https://github.com/libuv/libuv/archive/refs/tags/v$Version.zip"
    Write $TarUrl
    $TarFile = "$env:TEMP\uv.zip"

    Invoke-WebRequest -Uri $TarUrl -OutFile $TarFile

    tar -xf $TarFile -C $env:TEMP
    Rename-Item "$env:TEMP\libuv-$Version" $SrcDir
    Remove-Item $TarFile
}

Set-Location $SrcDir

cmake -B build -S . -DBUILD_TESTING=ON -DCMAKE_INSTALL_PREFIX="$InstallDir"
if ($LASTEXITCODE -ne 0) { Write-Error "Configure failed"; exit 1 }

cmake --build build --config Release
if ($LASTEXITCODE -ne 0) { Write-Error "cmake build failed"; exit 1 }

cmake --install build --config Release
if ($LASTEXITCODE -ne 0) { Write-Error "cmake install failed"; exit 1 }

$TarTarget = "$PackagesDir\uv-$Version-x64-windows-msvc-static.tar.gz"
tar -czf $TarTarget -C $InstallDir .
} finally {
    Set-Location $OrigDir
}
