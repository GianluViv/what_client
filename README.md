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
.\build_portable.ps1     # singolo .exe Windows, con Chromium incluso
```

L'eseguibile portable funziona su Windows senza Flutter, WebView2 o Chrome;
se non e' firmato digitalmente, Windows puo' visualizzare SmartScreen al primo
avvio.

Dettagli architetturali e motivazione della migrazione sono in
[docs/electron-migration.md](docs/electron-migration.md).
