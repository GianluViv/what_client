#!/usr/bin/env bash
# Crea un singolo file AppImage Linux, completo di Electron/Chromium.
# Uso: ./build_appimage.sh [--install-dependencies]
# Eseguire nativamente su Linux (o in una CI Linux).

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$project_root"

if [[ "${1:-}" == "--install-dependencies" ]]; then
  echo '==> Installo le dipendenze npm'
  npm ci
fi

echo '==> Creo AppImage Linux'
npm run dist:appimage

artifact="$(find "$project_root/dist" -maxdepth 1 -type f -name '*.AppImage' -printf '%T@ %p\n' | sort -nr | head -n 1 | cut -d' ' -f2-)"
if [[ -z "$artifact" ]]; then
  echo 'Artefatto AppImage non trovato in ./dist.' >&2
  exit 1
fi

release_dir="$project_root/release_appimage"
mkdir -p "$release_dir"
destination="$release_dir/$(basename "$artifact")"
install -m 755 "$artifact" "$destination"

echo "==> Pronto: $destination"
echo 'Distribuire questo singolo file. Su sistemi senza FUSE 2 usare: ./file.AppImage --appimage-extract-and-run'
