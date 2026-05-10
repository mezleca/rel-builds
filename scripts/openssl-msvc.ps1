param(
    [string]$Version = "3.3.1"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$PackagesDir = "$PSScriptRoot\..\packages"
$SrcDir      = "$env:TEMP\openssl-src"
$InstallDir  = "$env:TEMP\openssl-install"

New-Item -ItemType Directory -Force -Path $PackagesDir | Out-Null

$OrigDir = $PWD.Path
$VcVars = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat"

if (-not (Test-Path $VcVars)) {
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
    $Tag     = "openssl-$Version"
    $TarUrl  = "https://github.com/openssl/openssl/releases/download/$Tag/$Tag.tar.gz"
    $TarFile = "$env:TEMP\openssl.tar.gz"

    Invoke-WebRequest -Uri $TarUrl -OutFile $TarFile

    tar -xzf $TarFile -C $env:TEMP
    Rename-Item "$env:TEMP\openssl-$Version" $SrcDir
    Remove-Item $TarFile
}

Set-Location $SrcDir
perl Configure VC-WIN64A `
    no-shared `
    no-ssl3 `
    no-comp `
    no-makedepend `
    --prefix="$InstallDir" `
    --openssldir="$InstallDir\ssl"

if ($LASTEXITCODE -ne 0) { Write-Error "Configure failed"; exit 1 }

nmake
if ($LASTEXITCODE -ne 0) { Write-Error "nmake failed"; exit 1 }

nmake install_sw
if ($LASTEXITCODE -ne 0) { Write-Error "nmake install failed"; exit 1 }

$TarTarget = "$PackagesDir\openssl-$Version-x64-windows-msvc-static.tar.gz"
tar -czf $TarTarget -C $InstallDir .
} finally {
    Set-Location $OrigDir
}
