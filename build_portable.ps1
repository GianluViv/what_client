# build_portable.ps1
# Crea una build Windows "portable" di what_client in una cartella nella radice del progetto.
# La release Windows di Flutter e' gia' autocontenuta (exe + DLL + cartella data):
# basta copiarla in una cartella dedicata e si puo' spostare/zippare a piacere.
#
# Uso:
#   .\build_portable.ps1            # build release + copia in .\portable
#   .\build_portable.ps1 -Zip       # crea anche un archivio .zip
#   .\build_portable.ps1 -SkipBuild # salta 'flutter build' e copia l'output esistente

param(
    [switch]$Zip,
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'

# Radice del progetto = cartella di questo script
$ProjectRoot = $PSScriptRoot
Set-Location $ProjectRoot

$BuildOutput = Join-Path $ProjectRoot 'build\windows\x64\runner\Release'
$AppName     = 'what_client'
$DestName    = "$AppName-portable"
$DestDir     = Join-Path $ProjectRoot $DestName

# --- 1. Build ---------------------------------------------------------------
if (-not $SkipBuild) {
    Write-Host "==> flutter build windows --release" -ForegroundColor Cyan
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw "flutter build windows fallita (exit $LASTEXITCODE)" }
} else {
    Write-Host "==> SkipBuild: uso l'output esistente" -ForegroundColor Yellow
}

if (-not (Test-Path $BuildOutput)) {
    throw "Output di build non trovato: $BuildOutput. Esegui prima 'flutter build windows --release'."
}

# --- 2. Copia nella cartella portable ---------------------------------------
Write-Host "==> Preparo $DestDir" -ForegroundColor Cyan
if (Test-Path $DestDir) {
    Remove-Item $DestDir -Recurse -Force
}
New-Item -ItemType Directory -Path $DestDir | Out-Null

Copy-Item -Path (Join-Path $BuildOutput '*') -Destination $DestDir -Recurse -Force

$Exe = Join-Path $DestDir "$AppName.exe"
if (-not (Test-Path $Exe)) {
    Write-Host "Attenzione: $AppName.exe non trovato nella cartella copiata." -ForegroundColor Yellow
}

Write-Host "==> Build portable pronta in: $DestDir" -ForegroundColor Green

# --- 3. (Opzionale) Zip -----------------------------------------------------
if ($Zip) {
    $ZipPath = Join-Path $ProjectRoot "$DestName.zip"
    if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
    Write-Host "==> Creo archivio $ZipPath" -ForegroundColor Cyan
    Compress-Archive -Path (Join-Path $DestDir '*') -DestinationPath $ZipPath
    Write-Host "==> Archivio pronto: $ZipPath" -ForegroundColor Green
}
