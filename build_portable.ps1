# build_portable.ps1
# Crea una build Windows "portable" di what_client in una cartella nella radice del progetto.
# La release Windows di Flutter e' gia' autocontenuta (exe + DLL + cartella data):
# basta copiarla in una cartella dedicata e si puo' spostare/zippare a piacere.
#
# NON impacchettare il risultato in un unico exe con Enigma Virtual Box (o strumenti
# di virtualizzazione/protezione EXE simili): what_client usa webview_all_windows, che
# compone il contenuto WebView2 tramite Windows.Graphics.Capture / DirectComposition
# (packages\webview_all_windows\windows\webview_platform.cc). L'hooking a basso livello
# delle API di file-system che questi tool applicano al processo interferisce con
# l'inizializzazione del processo GPU/sandbox di WebView2 e con l'handoff della
# superficie di composizione: il risultato e' una finestra permanentemente nera al posto
# di WhatsApp, anche se il resto della UI Flutter nativa funziona. Verificato: la stessa
# cartella non impacchettata funziona correttamente. Se in futuro serve di nuovo un
# singolo exe portabile, usare un self-extracting archive (es. 7-Zip SFX, gia'
# disponibile su questa macchina in "C:\Program Files\7-Zip\7z.sfx") che estrae la
# cartella intatta e lancia l'exe reale, invece di virtualizzare il processo in memoria.
#
# Uso:
#   .\build_portable.ps1                 # build release + copia in .\what_client-portable
#   .\build_portable.ps1 -Zip            # crea anche un archivio .zip della cartella
#   .\build_portable.ps1 -SkipBuild      # salta 'flutter build' e copia l'output esistente

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
