import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:webview_all_linux/webview_all_linux.dart';
import 'package:webview_all_windows/webview_all_windows.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:window_manager/window_manager.dart';

const _whatsAppUrl = 'https://web.whatsapp.com';
const _userAgent =
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36';

const _keyMinimizeToTray = 'minimize_to_tray';

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isLinux) LinuxWebViewPlatform.registerWith();
  if (Platform.isWindows) WindowsWebViewPlatform.registerWith();

  await windowManager.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final minimizeToTray = prefs.getBool(_keyMinimizeToTray) ?? false;

  await windowManager.waitUntilReadyToShow(
    WindowOptions(
      title: 'WhatsApp',
      size: const Size(1200, 800),
      minimumSize: const Size(800, 600),
      center: true,
      titleBarStyle:
          Platform.isLinux ? TitleBarStyle.hidden : TitleBarStyle.normal,
    ),
    () async {
      // Prevent default close; onWindowClose() decides what to do.
      await windowManager.setPreventClose(true);
      await windowManager.show();
      await windowManager.focus();
    },
  );

  runApp(WhatsAppApp(initialMinimizeToTray: minimizeToTray));
}

// ---------------------------------------------------------------------------
// App root
// ---------------------------------------------------------------------------

class WhatsAppApp extends StatelessWidget {
  final bool initialMinimizeToTray;

  // Navigator key so TrayListener can pop routes when restoring from tray.
  static final navigatorKey = GlobalKey<NavigatorState>();

  const WhatsAppApp({super.key, required this.initialMinimizeToTray});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'WhatsApp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF25D366)),
        useMaterial3: true,
      ),
      home: WhatsAppView(initialMinimizeToTray: initialMinimizeToTray),
    );
  }
}

// ---------------------------------------------------------------------------
// Main webview screen
// ---------------------------------------------------------------------------

class WhatsAppView extends StatefulWidget {
  final bool initialMinimizeToTray;

  const WhatsAppView({super.key, required this.initialMinimizeToTray});

  @override
  State<WhatsAppView> createState() => _WhatsAppViewState();
}

class _WhatsAppViewState extends State<WhatsAppView>
    with WindowListener, TrayListener {
  late final WebViewController _controller;
  final _progress = ValueNotifier<int>(0);
  final _webviewBoundaryKey = GlobalKey();
  bool _repaintActive = false;

  late bool _minimizeToTray;
  bool _trayReady = false;

  // ── init / dispose ────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _minimizeToTray = widget.initialMinimizeToTray;

    windowManager.addListener(this);
    if (_minimizeToTray) _setupTray();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_userAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => _progress.value = 0,
          onProgress: (p) => _progress.value = p,
          onPageFinished: (_) => _progress.value = 100,
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null ||
                (uri.scheme != 'https' && uri.scheme != 'http')) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(_whatsAppUrl));

    if (Platform.isLinux) {
      _repaintActive = true;
      WidgetsBinding.instance.addPersistentFrameCallback(_onPersistentFrame);
    }
  }

  @override
  void dispose() {
    _repaintActive = false;
    windowManager.removeListener(this);
    if (_trayReady) trayManager.removeListener(this);
    _progress.dispose();
    super.dispose();
  }

  // ── repaint loop (Linux only) ─────────────────────────────────────────────

  void _onPersistentFrame(Duration _) {
    if (!_repaintActive) return;
    _webviewBoundaryKey.currentContext?.findRenderObject()?.markNeedsPaint();
  }

  // ── window listener ───────────────────────────────────────────────────────

  @override
  void onWindowClose() async {
    if (_minimizeToTray) {
      await windowManager.hide();
    } else {
      await windowManager.destroy();
    }
  }

  // ── tray listener ─────────────────────────────────────────────────────────

  @override
  void onTrayIconMouseDown() => _restoreWindow();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show') {
      _restoreWindow();
    } else if (menuItem.key == 'quit') {
      windowManager.destroy();
    }
  }

  void _restoreWindow() {
    // Pop back to the main webview route (closes settings if open).
    WhatsAppApp.navigatorKey.currentState
        ?.popUntil((route) => route.isFirst);
    windowManager.show();
    windowManager.focus();
  }

  // ── tray setup / teardown ─────────────────────────────────────────────────

  Future<void> _setupTray() async {
    if (_trayReady) return;
    try {
      await trayManager.setIcon('assets/icons/tray_icon.png');
      await trayManager.setContextMenu(Menu(items: [
        MenuItem(key: 'show', label: 'Apri WhatsApp'),
        MenuItem.separator(),
        MenuItem(key: 'quit', label: 'Esci'),
      ]));
      trayManager.addListener(this);
      _trayReady = true;
    } catch (e) {
      debugPrint('Tray init failed: $e');
    }
  }

  Future<void> _teardownTray() async {
    if (!_trayReady) return;
    try {
      trayManager.removeListener(this);
      await trayManager.destroy();
      _trayReady = false;
    } catch (e) {
      debugPrint('Tray teardown failed: $e');
    }
  }

  // ── settings ──────────────────────────────────────────────────────────────

  Future<void> _onMinimizeToTrayChanged(bool value) async {
    setState(() => _minimizeToTray = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyMinimizeToTray, value);
    if (value) {
      await _setupTray();
    } else {
      await _teardownTray();
    }
  }

  void _openSettings() {
    // PageRouteBuilder with zero duration: the webview route is immediately
    // occluded, so paint() is not called → webview_all_linux hides WebKit →
    // the settings screen renders in full without the overlay on top.
    Navigator.of(context).push(PageRouteBuilder<void>(
      opaque: true,
      pageBuilder: (_, _, _) => SettingsScreen(
        minimizeToTray: _minimizeToTray,
        onMinimizeToTrayChanged: _onMinimizeToTrayChanged,
      ),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ));
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (Platform.isLinux)
            AppTitleBar(
              leading: const Padding(
                padding: EdgeInsets.only(left: 10),
                child: Icon(Icons.chat_bubble, color: Color(0xFF25D366), size: 14),
              ),
              title: 'WhatsApp',
              actions: [
                TitleBarButton(
                  icon: Icons.settings_outlined,
                  tooltip: 'Impostazioni',
                  onPressed: _openSettings,
                ),
              ],
            ),
          Expanded(
            child: Stack(
              children: [
                RepaintBoundary(
                  key: _webviewBoundaryKey,
                  child: WebViewWidget(controller: _controller),
                ),
                ValueListenableBuilder<int>(
                  valueListenable: _progress,
                  builder: (context, progress, _) {
                    if (progress >= 100) return const SizedBox.shrink();
                    return LinearProgressIndicator(
                      value: progress == 0 ? null : progress / 100,
                      backgroundColor: Colors.transparent,
                      color: const Color(0xFF25D366),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Settings screen
// ---------------------------------------------------------------------------

class SettingsScreen extends StatefulWidget {
  final bool minimizeToTray;
  final ValueChanged<bool> onMinimizeToTrayChanged;

  const SettingsScreen({
    super.key,
    required this.minimizeToTray,
    required this.onMinimizeToTrayChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _minimizeToTray;

  @override
  void initState() {
    super.initState();
    _minimizeToTray = widget.minimizeToTray;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111B21),
      body: Column(
        children: [
          if (Platform.isLinux)
            AppTitleBar(
              leading: TitleBarButton(
                icon: Icons.arrow_back,
                tooltip: 'Indietro',
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: 'Impostazioni',
              actions: const [],
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
              children: [
                _SectionHeader('Comportamento'),
                _SettingsTile(
                  icon: Icons.logout,
                  title: 'Riduci nel system tray alla chiusura',
                  subtitle:
                      'La pressione di × nasconde la finestra nel tray invece di uscire.',
                  trailing: Switch.adaptive(
                    value: _minimizeToTray,
                    activeTrackColor: const Color(0xFF25D366),
                    onChanged: (v) {
                      setState(() => _minimizeToTray = v);
                      widget.onMinimizeToTrayChanged(v);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF25D366),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2C34),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(icon, color: Colors.white54, size: 22),
        title: Text(title,
            style: const TextStyle(color: Colors.white, fontSize: 14)),
        subtitle: Text(subtitle,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        trailing: trailing,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared title bar widget
// ---------------------------------------------------------------------------

class AppTitleBar extends StatelessWidget {
  final Widget? leading;
  final String title;
  final List<Widget> actions;

  const AppTitleBar({
    super.key,
    this.leading,
    required this.title,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ColoredBox(
        color: const Color(0xFF1F2C34),
        child: Row(
          children: [
            ?leading,
            Expanded(
              child: GestureDetector(
                onDoubleTap: () async {
                  if (await windowManager.isMaximized()) {
                    windowManager.unmaximize();
                  } else {
                    windowManager.maximize();
                  }
                },
                child: DragToMoveArea(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ...actions,
            TitleBarButton(
              icon: Icons.remove,
              tooltip: 'Minimizza',
              onPressed: () => windowManager.minimize(),
            ),
            TitleBarButton(
              icon: Icons.crop_square,
              tooltip: 'Massimizza / Ripristina',
              onPressed: () async {
                if (await windowManager.isMaximized()) {
                  windowManager.unmaximize();
                } else {
                  windowManager.maximize();
                }
              },
            ),
            TitleBarButton(
              icon: Icons.close,
              tooltip: 'Chiudi',
              onPressed: () => windowManager.close(),
              isClose: true,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Title bar icon button with hover highlight
// ---------------------------------------------------------------------------

class TitleBarButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isClose;

  const TitleBarButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isClose = false,
  });

  @override
  State<TitleBarButton> createState() => _TitleBarButtonState();
}

class _TitleBarButtonState extends State<TitleBarButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: SizedBox(
            width: 40,
            height: 32,
            child: ColoredBox(
              color: _hovered
                  ? (widget.isClose
                      ? const Color(0xFFE81123)
                      : Colors.white.withValues(alpha: 0.12))
                  : Colors.transparent,
              child: Center(
                child: Icon(widget.icon, color: Colors.white70, size: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
