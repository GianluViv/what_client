'use strict';

const minimize = document.querySelector('#minimize');
const width = document.querySelector('#chat-width');
const widthValue = document.querySelector('#chat-width-value');

function showWidth(value) {
  widthValue.textContent = value == null ? 'Predefinita' : `${value}px`;
}

async function save(patch) {
  const settings = await window.whatClient.saveSettings(patch);
  minimize.checked = settings.minimizeToTray;
  width.value = settings.chatListWidth ?? 400;
  showWidth(settings.chatListWidth);
}

window.whatClient.getSettings().then((settings) => {
  minimize.checked = settings.minimizeToTray;
  width.value = settings.chatListWidth ?? 400;
  showWidth(settings.chatListWidth);
});

minimize.addEventListener('change', () => save({ minimizeToTray: minimize.checked }));
width.addEventListener('input', () => {
  widthValue.textContent = `${width.value}px`;
});
width.addEventListener('change', () => save({ chatListWidth: Number(width.value) }));
document.querySelector('#reset').addEventListener('click', () => save({ chatListWidth: null }));
document.querySelector('#close').addEventListener('click', () => window.whatClient.closeSettings());
