'use strict';

const { contextBridge, ipcRenderer } = require('electron');

// This is deliberately a narrow bridge: the remote WhatsApp page can only
// persist a validated chat-column width, never invoke arbitrary IPC methods.
contextBridge.exposeInMainWorld('whatClientLayout', {
  setChatWidth: (width) => ipcRenderer.send('layout:set-chat-width', width),
});
