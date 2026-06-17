# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`what_client` is a Flutter **desktop** application (Linux + Windows only — there are no
Android/iOS/macOS/web targets) that wraps **WhatsApp Web** (`https://web.whatsapp.com`)
in a `WebView`. Essentially the entire application lives in a single file:
[lib/main.dart](lib/main.dart). UI strings are in Italian.

## Commands

```bash
flutter pub get                 # install dependencies (also resolves the path: packages)
flutter run -d linux            # run on Linux
flutter run -d windows          # run on Windows
flutter build linux             # release build
flutter build windows
flutter analyze                 # static analysis / lint (flutter_lints, see analysis_options.yaml)
flutter test                    # run all tests
flutter test test/widget_test.dart --plain-name 'App smoke test'   # run a single test
```

Note: the smoke test in [test/widget_test.dart](test/widget_test.dart) constructs
`WhatsAppApp()` with no arguments, but the constructor now **requires**
`initialMinimizeToTray`. The test will not compile until updated — keep it in sync when
changing constructor signatures.

## Architecture

Single-file structure in [lib/main.dart](lib/main.dart), with platform behavior branched
on `Platform.isLinux` / `Platform.isWindows` throughout:

- **`main()`** — registers the per-platform WebView implementation
  (`LinuxWebViewPlatform` / `WindowsWebViewPlatform`), initializes `window_manager`, reads
  the persisted `minimize_to_tray` preference, then shows the window. `setPreventClose(true)`
  is set so that the close button is intercepted by `onWindowClose()` rather than killing
  the process.
- **`WhatsAppView`** — the main screen holding the `WebViewController`. Mixes in
  `WindowListener` + `TrayListener`. A static `navigatorKey` (on `WhatsAppApp`) lets the
  tray listener pop back to the webview route when restoring the window.
- **`SettingsScreen`** — a single toggle ("minimize to tray"), persisted via
  `shared_preferences` under the key `minimize_to_tray`.

### Three platform-specific behaviors that are easy to break

1. **Custom title bar (Linux only).** On Linux the native title bar is hidden
   (`TitleBarStyle.hidden`) and `AppTitleBar` / `TitleBarButton` reimplement minimize /
   maximize / close + drag. On Windows the OS title bar is used. Any title-bar change must
   stay inside the `if (Platform.isLinux)` branches.

2. **Linux repaint loop.** `webview_all_linux` renders WebKitGTK in a native layer that
   does not repaint on its own, so `_onPersistentFrame` calls `markNeedsPaint()` on the
   webview's `RepaintBoundary` every frame (gated by `_repaintActive`, Linux only). Do not
   remove this — the webview goes blank without it.

3. **Settings navigation uses a zero-duration `PageRouteBuilder`.** `_openSettings()` is
   deliberately not a normal animated push: an instant opaque transition fully occludes the
   webview route so its `paint()` stops being called, which makes `webview_all_linux` hide
   the WebKit surface. Otherwise the native WebKit layer would draw on top of the settings
   screen. Preserve `opaque: true` + `Duration.zero`.

### Tray lifecycle

The tray icon is created/destroyed dynamically based on the setting (`_setupTray` /
`_teardownTray`), not at startup. `_trayReady` guards against double init/teardown and
ensures the `TrayListener` is only attached when a tray exists. Tray icon asset:
`assets/icons/tray_icon.png`.

## Vendored packages

`packages/` contains local copies wired in via `path:` dependencies in
[pubspec.yaml](pubspec.yaml):

- **`webview_all_linux`** — WebKitGTK-backed WebView for Linux (implements the
  `webview_all` / `webview_flutter_platform_interface`). Windows uses the pub.dev
  `webview_all_windows`.
- **`tray_manager`** — system tray support.

Treat these as third-party source: prefer changing `lib/main.dart` over editing them, and
expect them to have their own `example/` and tests that are not part of this app.
