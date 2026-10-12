# AGENTS.md

## Progetto

`what_client` e' un client desktop Linux/Windows per WhatsApp Web basato su
Electron e Chromium. Il runtime e il packaging sono definiti in
`package.json`.

## Comandi

```bash
npm install
npm start
npm run dist:linux
npm run dist:win
```

## Architettura

- `electron/main.js`: processo principale; finestra WhatsApp, tray, download,
  permessi, istanza singola e persistenza impostazioni.
- `electron/whatsapp-preload.js`: bridge IPC minimo per la larghezza della
  lista chat. Non esporre API Node generiche alla pagina remota.
- `electron/settings.*` e `electron/preload.js`: finestra impostazioni locale.
- `assets/icons/`: icone applicazione e tray.

WhatsApp e' contenuto remoto: mantenere `contextIsolation: true`,
`nodeIntegration: false` e validare ogni messaggio IPC. La finestra viene
nascosta (non distrutta) quando `minimizeToTray` e' attivo per mantenere
connessione e badge non letti.

La scelta Electron e le funzionalita' migrate sono documentate in
`docs/electron-migration.md`.
