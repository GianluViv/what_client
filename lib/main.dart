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
    const WindowOptions(
      title: 'WhatsApp',
      size: Size(1200, 800),
      minimumSize: Size(800, 600),
      center: true,
      titleBarStyle: TitleBarStyle.normal,
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );

  runApp(const WhatsAppApp());
}

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

class WhatsAppView extends StatefulWidget {
  const WhatsAppView({super.key});

  @override
  State<WhatsAppView> createState() => _WhatsAppViewState();
}

class _WhatsAppViewState extends State<WhatsAppView> {
  late final WebViewController _controller;
  final _progress = ValueNotifier<int>(0);

  // Su Linux webview_all_linux traccia la visibilità del webkit overlay
  // controllando se il geometry observer riceve paint() ad ogni frame Flutter.
  // Usiamo addPersistentFrameCallback per segnare il boundary come dirty
  // all'inizio di OGNI frame (handleBeginFrame), prima della fase di paint.
  // Questo garantisce che paint() venga sempre chiamato, prevenendo sia
  // lo schermo bianco (overlay nascosto) sia il focus steal (gtk_widget_grab_focus
  // chiamato ogni volta che l'overlay viene re-mostrato dopo essere stato nascosto).
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
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
    );
  }
}
