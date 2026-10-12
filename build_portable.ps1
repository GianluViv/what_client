# Crea un singolo eseguibile Windows portabile, completo di Chromium.
# Uso: .\build_portable.ps1 [-InstallDependencies]
# Il risultato non richiede Flutter, WebView2 o un'installazione di Chrome.

param(
    [switch]$InstallDependencies
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = $PSScriptRoot
Set-Location $ProjectRoot

if ($InstallDependencies) {
    Write-Host '==> Installo le dipendenze npm' -ForegroundColor Cyan
    npm ci
    if ($LASTEXITCODE -ne 0) { throw "npm ci fallito (exit $LASTEXITCODE)" }
}

Write-Host '==> Creo l''eseguibile portabile Windows' -ForegroundColor Cyan
npm run dist:portable
if ($LASTEXITCODE -ne 0) { throw "Build portable fallita (exit $LASTEXITCODE)" }

$Artifact = Get-ChildItem -Path (Join-Path $ProjectRoot 'dist') -Filter '*-portable-*.exe' |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
if (-not $Artifact) { throw 'Artefatto portable non trovato in .\dist.' }

$ReleaseDir = Join-Path $ProjectRoot 'release_portable'
New-Item -ItemType Directory -Force -Path $ReleaseDir | Out-Null
$Destination = Join-Path $ReleaseDir $Artifact.Name
Copy-Item -LiteralPath $Artifact.FullName -Destination $Destination -Force

Write-Host "==> Pronto: $Destination" -ForegroundColor Green
Write-Host 'Distribuire questo singolo .exe. Al primo avvio Windows potrebbe mostrare SmartScreen se il file non e'' firmato.' -ForegroundColor Yellow
