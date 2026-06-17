#!/usr/bin/env bash
# Creates WhatsApp.AppImage from the Flutter Linux release build.
#
# Requirements on the build machine:
#   - Flutter SDK in PATH
#   - FUSE (for appimagetool to run):  sudo pacman -S fuse2   (Arch)
#   - Or run appimagetool with --appimage-extract-and-run if FUSE is unavailable
#
# The resulting AppImage requires on the *target* machine:
#   - GTK 3, WebKit2GTK 4.x  (standard on any modern Linux desktop)
#
set -euo pipefail

APP_NAME="WhatsApp"
BINARY_NAME="what_client"
DESKTOP_ID="com.teststudio.what_client"
OUTPUT="${APP_NAME}-x86_64.AppImage"

BUNDLE="build/linux/x64/release/bundle"
APPDIR="build/${APP_NAME}.AppDir"

# ── 1. Flutter release build ─────────────────────────────────────────────────
echo "→ Building Flutter release…"
flutter build linux --release

# ── 2. Build AppDir ──────────────────────────────────────────────────────────
echo "→ Creating AppDir…"
rm -rf "$APPDIR"
mkdir -p "$APPDIR"

# Copy the entire Flutter bundle into AppDir
cp -r "${BUNDLE}/." "$APPDIR/"

# ── 3. AppRun ────────────────────────────────────────────────────────────────
cat > "$APPDIR/AppRun" << 'APPRUN'
#!/usr/bin/env bash
SELF=$(readlink -f "$0")
HERE=$(dirname "$SELF")
# Prepend the bundled libs so libflutter_linux_gtk.so is found first.
export LD_LIBRARY_PATH="${HERE}/lib:${LD_LIBRARY_PATH:-}"
exec "${HERE}/what_client" "$@"
APPRUN
chmod +x "$APPDIR/AppRun"

# ── 4. .desktop file ─────────────────────────────────────────────────────────
cat > "$APPDIR/${DESKTOP_ID}.desktop" << DESKTOP
[Desktop Entry]
Version=1.0
Type=Application
Name=${APP_NAME}
Exec=${BINARY_NAME}
Icon=${BINARY_NAME}
Categories=Network;InstantMessaging;
StartupWMClass=${BINARY_NAME}
DESKTOP

# ── 5. Icon (256×256 required at AppDir root, named like the Exec field) ─────
cp "assets/icons/hicolor/256x256/apps/tray_icon.png" "$APPDIR/${BINARY_NAME}.png"

# Also plant the full hicolor tree so desktop environments that read the
# AppImage's icon theme find the correct sizes.
mkdir -p "$APPDIR/usr/share/icons/hicolor/256x256/apps"
mkdir -p "$APPDIR/usr/share/icons/hicolor/32x32/apps"
cp "assets/icons/hicolor/256x256/apps/tray_icon.png" \
   "$APPDIR/usr/share/icons/hicolor/256x256/apps/${BINARY_NAME}.png"
cp "assets/icons/hicolor/32x32/apps/tray_icon.png" \
   "$APPDIR/usr/share/icons/hicolor/32x32/apps/${BINARY_NAME}.png"

# ── 6. Download appimagetool if not in PATH ───────────────────────────────────
APPIMAGETOOL=$(command -v appimagetool 2>/dev/null || true)
if [[ -z "$APPIMAGETOOL" ]]; then
    APPIMAGETOOL="/tmp/appimagetool-x86_64"
    if [[ ! -x "$APPIMAGETOOL" ]]; then
        echo "→ Downloading appimagetool…"
        curl -L -o "$APPIMAGETOOL" \
            "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
        chmod +x "$APPIMAGETOOL"
    fi
fi

# ── 7. Pack ───────────────────────────────────────────────────────────────────
echo "→ Packing AppImage…"
# --appimage-extract-and-run avoids needing FUSE on the build machine itself.
ARCH=x86_64 "$APPIMAGETOOL" --appimage-extract-and-run "$APPDIR" "$OUTPUT"

echo ""
echo "✓ Done: $OUTPUT"
echo "  Size: $(du -sh "$OUTPUT" | cut -f1)"
