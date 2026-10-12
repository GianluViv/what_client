'use strict';

const { app, BrowserWindow, ipcMain, Menu, Tray, Notification, session, shell } = require('electron');
const fs = require('node:fs');
const path = require('node:path');

const WHATSAPP_URL = 'https://web.whatsapp.com/';
const WHATSAPP_PARTITION = 'persist:whatsapp';
const WHATSAPP_HOSTS = new Set(['web.whatsapp.com', 'whatsapp.com', 'www.whatsapp.com']);
let mainWindow;
let settingsWindow;
let tray;
let quitting = false;
let hasUnread = false;
let sessionConfigured = false;
let settings = { minimizeToTray: false, chatListWidth: null };

const assetPath = (...parts) => path.join(__dirname, '..', ...parts);
const settingsPath = () => path.join(app.getPath('userData'), 'settings.json');

function loadSettings() {
  try {
    const parsed = JSON.parse(fs.readFileSync(settingsPath(), 'utf8'));
    settings.minimizeToTray = parsed.minimizeToTray === true;
    settings.chatListWidth = Number.isInteger(parsed.chatListWidth) &&
      parsed.chatListWidth >= 280 && parsed.chatListWidth <= 600
      ? parsed.chatListWidth
      : null;
  } catch {
    // First launch or corrupt settings: retain safe defaults.
  }
}

function saveSettings() {
  fs.mkdirSync(path.dirname(settingsPath()), { recursive: true });
  fs.writeFileSync(settingsPath(), `${JSON.stringify(settings, null, 2)}\n`);
}

function showMainWindow() {
  // The process remains alive for the tray even if the user chose normal
  // close. In that case BrowserWindow has already been destroyed: recreate it.
  if (!mainWindow || mainWindow.isDestroyed()) {
    mainWindow = undefined;
    createWindow();
    return;
  }
  if (mainWindow.isMinimized()) mainWindow.restore();
  mainWindow.show();
  mainWindow.focus();
}

function toggleMainWindow() {
  if (mainWindow && !mainWindow.isDestroyed() && mainWindow.isVisible()) {
    mainWindow.hide();
  } else {
    showMainWindow();
  }
}

function isWhatsAppUrl(rawUrl) {
  try {
    const url = new URL(rawUrl);
    return url.protocol === 'https:' &&
      [...WHATSAPP_HOSTS].some((host) => url.hostname === host || url.hostname.endsWith(`.${host}`));
  } catch {
    return false;
  }
}

async function applyChatListWidth() {
  if (!mainWindow || mainWindow.webContents.isDestroyed()) return;
  // Keep the resize handle and separator repair inside the document. The
  // handle reports only a numeric width through the deliberately narrow
  // preload bridge; it cannot access Electron or Node APIs.
  const width = JSON.stringify(settings.chatListWidth);
  await mainWindow.webContents.executeJavaScript(`
(() => {
  const W = ${width}, MIN = 280, MAX = 600, HANDLE = 'what-client-resize-handle';
  window.__whatClientChatWidth = W;
  let style = document.getElementById('what-client-chat-width');
  if (!style) { style = document.createElement('style'); style.id = 'what-client-chat-width'; document.head.appendChild(style); }
  style.textContent = W == null ? '' : 'div:has(> #side){flex:0 0 '+W+'px!important;width:'+W+'px!important;min-width:'+W+'px!important;max-width:'+W+'px!important;}';

  function restoreSeparators() {
    document.querySelectorAll('[data-what-client-separator]').forEach((node) => {
      node.style.removeProperty('border-left-color');
      node.style.removeProperty('border-left-width');
      node.style.removeProperty('border-left-style');
      node.removeAttribute('data-what-client-separator');
    });
  }
  function fixSeparators() {
    restoreSeparators();
    if (window.__whatClientChatWidth == null) return;
    const side = document.getElementById('side');
    const column = side && side.parentElement;
    if (!column) return;
    let conversation = column.nextElementSibling;
    while (conversation && conversation.getBoundingClientRect().height < 300) conversation = conversation.nextElementSibling;
    // WhatsApp leaves a second, old-layout column with a faint border at the
    // former width. Hide those full-height faint borders, then draw exactly
    // one separator at the real conversation edge.
    document.querySelectorAll('div').forEach((node) => {
      if (node === conversation) return;
      const computed = getComputedStyle(node), rect = node.getBoundingClientRect();
      const alpha = (computed.borderLeftColor.match(/rgba?\\([^,]+,[^,]+,[^,]+(?:,\\s*([^)]+))?\\)/) || [])[1];
      if (computed.borderLeftStyle !== 'none' && parseFloat(computed.borderLeftWidth) >= 1 && rect.height > 300 && alpha !== undefined && Number(alpha) <= .4) {
        node.style.setProperty('border-left-color', 'transparent', 'important');
        node.setAttribute('data-what-client-separator', 'hidden');
      }
    });
    if (conversation) {
      conversation.style.setProperty('border-left-width', '1px', 'important');
      conversation.style.setProperty('border-left-style', 'solid', 'important');
      conversation.style.setProperty('border-left-color', 'rgba(0, 0, 0, 0.1)', 'important');
      conversation.setAttribute('data-what-client-separator', 'drawn');
    }
  }
  function positionHandle() {
    const side = document.getElementById('side');
    const handle = document.getElementById(HANDLE);
    if (!side || !handle) return;
    handle.style.left = (side.getBoundingClientRect().right - 3) + 'px';
  }
  let handle = document.getElementById(HANDLE);
  if (!handle) {
    handle = document.createElement('div'); handle.id = HANDLE;
    handle.style.cssText = 'position:fixed;top:0;width:6px;height:100vh;cursor:col-resize;z-index:2147483647;background:transparent;';
    handle.addEventListener('mouseenter', () => { handle.style.background = 'rgba(128,128,128,.18)'; });
    handle.addEventListener('mouseleave', () => { handle.style.background = 'transparent'; });
    handle.addEventListener('mousedown', (down) => {
      down.preventDefault();
      const side = document.getElementById('side'); if (!side) return;
      const startX = down.clientX, startWidth = side.getBoundingClientRect().width;
      document.body.style.userSelect = 'none';
      const move = (event) => {
        const next = Math.round(Math.max(MIN, Math.min(MAX, startWidth + event.clientX - startX)));
        window.__whatClientChatWidth = next;
        style.textContent = 'div:has(> #side){flex:0 0 '+next+'px!important;width:'+next+'px!important;min-width:'+next+'px!important;max-width:'+next+'px!important;}';
        positionHandle(); fixSeparators();
      };
      const up = (event) => {
        document.removeEventListener('mousemove', move); document.removeEventListener('mouseup', up);
        document.body.style.userSelect = '';
        const next = Math.round(Math.max(MIN, Math.min(MAX, startWidth + event.clientX - startX)));
        window.whatClientLayout?.setChatWidth(next);
      };
      document.addEventListener('mousemove', move); document.addEventListener('mouseup', up);
    });
    document.body.appendChild(handle);
  }
  positionHandle(); fixSeparators();
  if (!window.__whatClientLayoutObserver) {
    window.__whatClientLayoutObserver = new MutationObserver(() => {
      clearTimeout(window.__whatClientLayoutTimer);
      window.__whatClientLayoutTimer = setTimeout(() => { positionHandle(); fixSeparators(); }, 250);
    });
    window.__whatClientLayoutObserver.observe(document.body, { childList: true, subtree: true });
    window.addEventListener('resize', positionHandle);
  }
})()`, true).catch(() => {});
}

function updateTrayIcon() {
  if (!tray) return;
  const extension = process.platform === 'win32' ? 'ico' : 'png';
  const name = hasUnread ? `tray_icon_unread.${extension}` : `tray_icon.${extension}`;
  tray.setImage(assetPath('assets', 'icons', name));
}

function openSettings() {
  if (settingsWindow) {
    settingsWindow.focus();
    return;
  }
  settingsWindow = new BrowserWindow({
    title: 'Impostazioni', width: 520, height: 330, resizable: false,
    parent: mainWindow, modal: true, show: false,
    webPreferences: { preload: path.join(__dirname, 'preload.js'), contextIsolation: true, sandbox: true, nodeIntegration: false },
  });
  settingsWindow.removeMenu();
  settingsWindow.once('ready-to-show', () => settingsWindow?.show());
  settingsWindow.on('closed', () => { settingsWindow = undefined; });
  settingsWindow.loadFile(path.join(__dirname, 'settings.html'));
}

function createTray() {
  const icon = process.platform === 'win32'
    ? assetPath('assets', 'icons', 'tray_icon.ico')
    : assetPath('assets', 'icons', 'tray_icon.png');
  tray = new Tray(icon);
  tray.setToolTip('WhatsApp');
  tray.on('click', toggleMainWindow);
  refreshTrayMenu();
}

function refreshTrayMenu() {
  if (!tray) return;
  tray.setContextMenu(Menu.buildFromTemplate([
    { label: 'Mostra WhatsApp', click: showMainWindow },
    { label: 'Ricarica', click: () => mainWindow?.webContents.reload() },
    { label: 'Impostazioni', click: openSettings },
    { type: 'separator' },
    {
      label: 'Minimizza nel vassoio alla chiusura',
      type: 'checkbox',
      checked: settings.minimizeToTray,
      click: (item) => {
        settings.minimizeToTray = item.checked;
        saveSettings();
        refreshTrayMenu();
        settingsWindow?.webContents.send('settings:changed', settings);
      },
    },
    { type: 'separator' },
    { label: 'Esci', click: () => { quitting = true; app.quit(); } },
  ]));
}

function configureSession() {
  const whatsappSession = session.fromPartition(WHATSAPP_PARTITION);
  if (sessionConfigured) return whatsappSession;
  sessionConfigured = true;
  whatsappSession.setPermissionCheckHandler((_webContents, permission, requestingOrigin) =>
    isWhatsAppUrl(requestingOrigin) && ['notifications', 'media'].includes(permission));
  whatsappSession.setPermissionRequestHandler((_webContents, permission, callback, details) => {
    const allowed = isWhatsAppUrl(details.requestingUrl) &&
      ['notifications', 'media'].includes(permission);
    callback(allowed);
  });
  whatsappSession.on('will-download', (_event, item) => {
    // Electron shows the platform Save As UI; this also avoids silently writing
    // received files into Downloads.
    item.setSaveDialogOptions({ title: 'Salva file WhatsApp' });
    item.once('done', (_doneEvent, state) => {
      if (state === 'completed' && Notification.isSupported()) {
        new Notification({ title: 'WhatsApp', body: `Download completato: ${path.basename(item.getSavePath())}` }).show();
      }
    });
  });
  return whatsappSession;
}

function createWindow() {
  const whatsappSession = configureSession();
  mainWindow = new BrowserWindow({
    title: 'WhatsApp',
    width: 1200,
    height: 800,
    minWidth: 800,
    minHeight: 600,
    show: false,
    icon: assetPath('assets', 'icons', 'app_icon.png'),
    webPreferences: {
      partition: WHATSAPP_PARTITION,
      preload: path.join(__dirname, 'whatsapp-preload.js'),
      contextIsolation: true,
      sandbox: true,
      nodeIntegration: false,
    },
  });

  // `ready-to-show` may never arrive when the remote page is slow/offline.
  // Do not leave the application invisible in that case: show its native
  // window after a short fallback delay and let Chromium render the page later.
  const revealWindow = () => {
    if (mainWindow && !mainWindow.isVisible()) mainWindow.show();
  };
  // All application commands live in the tray; do not show Electron's
  // default native application menu above WhatsApp.
  mainWindow.removeMenu();
  mainWindow.once('ready-to-show', revealWindow);
  setTimeout(revealWindow, 1500);
  mainWindow.on('close', (event) => {
    if (!quitting && settings.minimizeToTray) {
      // Hide, do not destroy: WhatsApp remains connected and title updates can
      // continue to update the unread tray icon while the window is hidden.
      event.preventDefault();
      mainWindow.hide();
    }
  });
  mainWindow.on('closed', () => {
    mainWindow = undefined;
  });

  // WhatsApp Web rejects Electron's product token. Supply a conventional,
  // current Chrome desktop identity; Electron still provides the actual
  // Chromium engine and its capabilities.
  const platform = process.platform === 'win32'
    ? 'Windows NT 10.0; Win64; x64'
    : 'X11; Linux x86_64';
  mainWindow.webContents.setUserAgent(
    `Mozilla/5.0 (${platform}) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36`,
  );

  mainWindow.webContents.on('page-title-updated', (_event, title) => {
    hasUnread = /^\(\d+\)/.test(title);
    updateTrayIcon();
  });
  mainWindow.webContents.on('did-finish-load', applyChatListWidth);

  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    if (!isWhatsAppUrl(url)) shell.openExternal(url);
    return { action: 'deny' };
  });
  mainWindow.webContents.on('will-navigate', (event, url) => {
    if (!isWhatsAppUrl(url)) {
      event.preventDefault();
      shell.openExternal(url);
    }
  });
  mainWindow.webContents.loadURL(WHATSAPP_URL);
}

if (!app.requestSingleInstanceLock()) {
  app.quit();
} else {
  app.on('second-instance', showMainWindow);
  app.whenReady().then(() => {
    loadSettings();
    createWindow();
    createTray();
    ipcMain.handle('settings:get', () => settings);
    ipcMain.handle('settings:set', async (_event, patch) => {
      if (typeof patch?.minimizeToTray === 'boolean') settings.minimizeToTray = patch.minimizeToTray;
      if (patch && Object.hasOwn(patch, 'chatListWidth')) {
        settings.chatListWidth = Number.isInteger(patch.chatListWidth) &&
          patch.chatListWidth >= 280 && patch.chatListWidth <= 600 ? patch.chatListWidth : null;
      }
      saveSettings();
      refreshTrayMenu();
      await applyChatListWidth();
      return settings;
    });
    ipcMain.on('settings:close', () => settingsWindow?.close());
    ipcMain.on('layout:set-chat-width', async (event, width) => {
      if (event.sender !== mainWindow?.webContents) return;
      if (!Number.isInteger(width) || width < 280 || width > 600) return;
      settings.chatListWidth = width;
      saveSettings();
      await applyChatListWidth();
    });
    app.on('activate', () => {
      if (!mainWindow) createWindow();
      else showMainWindow();
    });
  });
}

app.on('before-quit', () => { quitting = true; });
app.on('window-all-closed', () => {
  // If close-to-tray is disabled, a normal close must terminate the app rather
  // than leaving a stale tray icon pointing at a destroyed BrowserWindow.
  if (process.platform !== 'darwin') app.quit();
});
