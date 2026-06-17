import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_all_linux/webview_all_linux.dart';
import 'package:webview_all_windows/webview_all_windows.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:window_manager/window_manager.dart';

const _whatsAppUrl = 'https://web.whatsapp.com';
const _userAgent =
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isLinux) LinuxWebViewPlatform.registerWith();
  if (Platform.isWindows) WindowsWebViewPlatform.registerWith();

  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    WindowOptions(
      title: 'WhatsApp',
      size: const Size(1200, 800),
      minimumSize: const Size(800, 600),
      center: true,
      // On Linux we draw a custom Flutter title bar so the WM one can be removed.
      // On Windows the WM title bar is retained (no floating webview issues there).
      titleBarStyle:
          Platform.isLinux ? TitleBarStyle.hidden : TitleBarStyle.normal,
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );

  runApp(const WhatsAppApp());
}

// ---------------------------------------------------------------------------
// App root
// ---------------------------------------------------------------------------

class WhatsAppApp extends StatelessWidget {
  const WhatsAppApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WhatsApp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF25D366)),
        useMaterial3: true,
      ),
      home: const WhatsAppView(),
    );
  }
}

// ---------------------------------------------------------------------------
// Main webview screen
// ---------------------------------------------------------------------------

class WhatsAppView extends StatefulWidget {
  const WhatsAppView({super.key});

  @override
  State<WhatsAppView> createState() => _WhatsAppViewState();
}

class _WhatsAppViewState extends State<WhatsAppView> {
  late final WebViewController _controller;
  final _progress = ValueNotifier<int>(0);

  // On Linux, webview_all_linux hides the WebKit overlay whenever Flutter
  // produces a frame without calling paint() on the geometry observer.
  // We mark the RepaintBoundary dirty at the start of every frame so that
  // paint() is always called, preventing both the white-screen (overlay
  // hidden) and the focus-steal (overlay re-shown → gtk_widget_grab_focus)
  // problems seen with addPostFrameCallback.
  final _webviewBoundaryKey = GlobalKey();
  bool _repaintActive = false;

  @override
  void initState() {
    super.initState();
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
            // Block non-http schemes (mailto:, tel:, blob:, etc.) to prevent
            // them from loading in the webview or opening external apps that
            // would steal window focus.
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

  void _onPersistentFrame(Duration _) {
    if (!_repaintActive) return;
    _webviewBoundaryKey.currentContext?.findRenderObject()?.markNeedsPaint();
  }

  @override
  void dispose() {
    _repaintActive = false;
    _progress.dispose();
    super.dispose();
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Custom title bar only on Linux (replaces WM-provided one).
          if (Platform.isLinux)
            AppTitleBar(
              leading: const Padding(
                padding: EdgeInsets.only(left: 12),
                child: Icon(
                  Icons.chat_bubble,
                  color: Color(0xFF25D366),
                  size: 16,
                ),
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
          // Webview fills the rest.
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

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
              padding: const EdgeInsets.all(24),
              children: const [
                _SettingsPlaceholder(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsPlaceholder extends StatelessWidget {
  const _SettingsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Impostazioni',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Nessuna impostazione disponibile al momento.',
          style: TextStyle(color: Colors.white54),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared title bar widget (used by both screens on Linux)
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
      height: 40,
      child: ColoredBox(
        color: const Color(0xFF1F2C34),
        child: Row(
          children: [
            ?leading,
            // Draggable title area (double-tap = toggle maximize)
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
            // Per-screen action buttons
            ...actions,
            // Standard window controls
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
            width: 46,
            height: 40,
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
