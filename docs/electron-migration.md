# Migrazione a Electron

## Decisione

Il client passa da Flutter con WebKitGTK su Linux e WebView2 su Windows a
Electron. L'app e' principalmente un contenitore di WhatsApp Web: usare il
motore Chromium incluso in Electron rende il comportamento della pagina uguale
su Linux e Windows.

La motivazione principale e' la compatibilita' della clipboard: WebKitGTK,
specialmente in sessioni Wayland, puo' non rendere disponibili a WhatsApp Web
le immagini appena create da strumenti di screenshot. Chromium gestisce il
percorso clipboard/drag-and-drop che WhatsApp Web testa normalmente.

## Conseguenze accettate

- Il pacchetto e il consumo di memoria aumentano, perche' Chromium viene
  distribuito con l'app.
- Il codice Flutter, i plugin WebView e i relativi script sono stati rimossi;
  la loro cronologia resta disponibile in Git.
- Tray, istanza singola, download e permessi sono ora responsabilita' del main
  process Electron, non di plugin nativi diversi per sistema operativo.

## Implementazione iniziale

La nuova app vive in `electron/` ed e' avviabile con `npm start`. Il main
process fornisce:

- una sola istanza e ripristino della finestra quando si tenta un secondo
  avvio;
- profilo Chromium persistente `persist:whatsapp`, separato dal profilo
  personale del browser;
- tray, badge non letti, menu in italiano e preferenza persistente
  `minimizeToTray`;
- finestra Impostazioni con minimizzazione nel tray e larghezza persistente
  dell'elenco chat (280--600 px); la regola CSS e' applicata direttamente alla
  pagina WhatsApp dopo ogni caricamento;
- dialogo nativo per i download e notifica al completamento;
- apertura esterna dei link che non sono WhatsApp;
- permessi limitati a notifiche, microfono e videocamera per gli origin
  WhatsApp.

La finestra carica direttamente `https://web.whatsapp.com`; quindi le funzioni
web (incluso l'incolla di immagini) restano gestite da Chromium. L'unica
personalizzazione iniettata e' la regola CSS opzionale per la larghezza della
lista chat.

Le vecchie scelte di colore/tema e lingua erano il tema della schermata
Impostazioni Flutter, non di WhatsApp Web. La nuova schermata nativa usa il
tema di sistema ed e' inizialmente in italiano; non vengono quindi mantenute
come preferenze prive di effetto.

## Comandi

```bash
npm install
npm start                 # sviluppo
npm run dist:linux        # pacchetto Linux
npm run dist:win          # pacchetto Windows
```

Le build sono configurate con `electron-builder`. Il packaging va eseguito sul
sistema di destinazione oppure in una CI che disponga degli strumenti di quel
sistema.

## Stato della migrazione

Il collaudo preliminare Windows ha verificato caricamento WhatsApp, clipboard,
tray, ripristino, larghezza chat e user-agent Chromium. Il runtime Flutter e'
stato quindi rimosso dal repository; un rollback resta possibile selezionando
un commit precedente nella cronologia Git. Restano da eseguire i test di
release e il collaudo equivalente su Linux.
