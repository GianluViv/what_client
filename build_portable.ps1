# build_portable.ps1
# Crea una build Windows "portable" di what_client in una cartella nella radice del progetto.
# La release Windows di Flutter e' gia' autocontenuta (exe + DLL + cartella data):
# basta copiarla in una cartella dedicata e si puo' spostare/zippare a piacere.
# Infine impacchetta il tutto in un unico exe portabile con Enigma Virtual Box
# (stesso approccio usato in collaudo_ariosa_valsir\scripts\pack_portable_exe.ps1).
#
# Uso:
#   .\build_portable.ps1                 # build release + copia in .\what_client-portable
#                                         #   + genera .\release_portable\what_client.exe (unico file)
#   .\build_portable.ps1 -Zip            # crea anche un archivio .zip della cartella
#   .\build_portable.ps1 -SkipBuild      # salta 'flutter build' e copia l'output esistente
#   .\build_portable.ps1 -SkipSingleExe  # salta il packaging nell'unico exe (Enigma Virtual Box)

param(
    [switch]$Zip,
    [switch]$SkipBuild,
    [switch]$SkipSingleExe
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
# Nota: si svuota il contenuto invece di rimuovere e ricreare la cartella stessa,
# perche' un editor/watcher (es. VSCode) puo' tenere un handle aperto sulla
# cartella di primo livello anche se i file al suo interno sono liberi.
Write-Host "==> Preparo $DestDir" -ForegroundColor Cyan
if (Test-Path $DestDir) {
    Get-ChildItem -LiteralPath $DestDir -Force | Remove-Item -Recurse -Force
} else {
    New-Item -ItemType Directory -Path $DestDir | Out-Null
}

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

# --- 4. Pacchettizza in un unico exe portabile -------------------------------
# Usa Enigma Virtual Box (richiede installazione a parte, vedi scripts\pack_portable_exe.ps1).
# Eseguito come processo figlio separato: se il tool manca, lo script termina con
# "exit 1" al suo interno, e questo non deve interrompere anche build_portable.ps1.
if (-not $SkipSingleExe) {
    $SingleExePath = Join-Path $ProjectRoot "release_portable\$AppName.exe"
    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ProjectRoot "scripts\pack_portable_exe.ps1") -ReleaseDir $DestDir -OutputExe $SingleExePath
    if ($LASTEXITCODE -eq 0) {
        Write-Host "==> Exe portabile unico pronto: $SingleExePath" -ForegroundColor Green
    }
    else {
        Write-Host "Packaging exe portabile saltato (vedi avviso sopra). La cartella $DestDir resta comunque utilizzabile." -ForegroundColor Yellow
    }
}
