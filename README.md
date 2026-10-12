# WhatsApp client

Client desktop per WhatsApp Web basato su Electron/Chromium, per Linux e
Windows.

```bash
npm install
npm start
```

Per creare i pacchetti:

```bash
npm run dist:linux
npm run dist:win
npm run dist:appimage
.\build_portable.ps1     # singolo .exe Windows, con Chromium incluso
./build_appimage.sh       # singolo AppImage Linux, con Chromium incluso
```

L'eseguibile portable funziona su Windows senza Flutter, WebView2 o Chrome;
se non e' firmato digitalmente, Windows puo' visualizzare SmartScreen al primo
avvio. Lo script AppImage va eseguito su Linux (o CI Linux) e produce un unico
file eseguibile senza dipendenze da WebKitGTK o Chrome.

Dettagli architetturali e motivazione della migrazione sono in
[docs/electron-migration.md](docs/electron-migration.md).
