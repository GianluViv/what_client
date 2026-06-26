import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:webview_all_linux/webview_all_linux.dart';
import 'package:webview_all_windows/webview_all_windows.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import 'l10n/app_localizations.dart';

const _whatsAppUrl = 'https://web.whatsapp.com';
const _userAgent =
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36';

// Localhost port used purely as a cross-platform single-instance lock. Binding
// it succeeds for the first copy only; a second copy fails to bind, signals the
// first to surface its window, then exits.
const _singleInstancePort = 45654;

const _keyMinimizeToTray = 'minimize_to_tray';
const _keyThemeMode = 'theme_mode';
const _keySeedColor = 'seed_color';
const _keyChatListWidth = 'chat_list_width';
const _keyLanguage = 'language';

const _defaultSeed = Color(0xFF25D366); // WhatsApp green

// Chat-list pane width override (px). Slider bounds; the initial position is
// WhatsApp's own default, measured from the live page when Settings opens.
const _minChatListWidth = 280.0;
const _maxChatListWidth = 600.0;
const _fallbackChatListWidth = 400.0; // used only if measuring the default fails

// Display names for the language picker. Driven by AppLocalizations.supportedLocales,
// so adding a new .arb file + entry here is sufficient — the dropdown updates automatically.
const _localeDisplayNames = <String, String>{
  'de': 'Deutsch',
  'el': 'Ελληνικά',
  'en': 'English',
  'es': 'Español',
  'fr': 'Français',
  'it': 'Italiano',
  'nl': 'Nederlands',
  'pl': 'Polski',
  'pt': 'Português',
  'ro': 'Română',
};

// Accent colors offered in Settings.
const _seedColorChoices = <Color>[
  Color(0xFF25D366), // WhatsApp green
  Color(0xFF128C7E), // teal
  Color(0xFF1DA1F2), // blue
  Color(0xFF7E57C2), // purple
  Color(0xFFFB8C00), // orange
  Color(0xFFE53935), // red
];

// ---------------------------------------------------------------------------
// Theme controller (theme mode + accent color, persisted)
// ---------------------------------------------------------------------------

class ThemeController extends ChangeNotifier {
  ThemeController(this._mode, this._seedColor, this._chatListWidth, this._languageCode);

  ThemeMode _mode;
  Color _seedColor;
  double? _chatListWidth; // null = use WhatsApp's default (no override)
  String? _languageCode; // null = follow OS locale

  ThemeMode get mode => _mode;
  Color get seedColor => _seedColor;
  double? get chatListWidth => _chatListWidth;
  String? get languageCode => _languageCode;
  Locale? get locale => _languageCode != null ? Locale(_languageCode!) : null;
  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, mode.name);
  }

  Future<void> setSeedColor(Color color) async {
    if (color.toARGB32() == _seedColor.toARGB32()) return;
    _seedColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySeedColor, color.toARGB32());
  }

  Future<void> setLanguage(String? code) async {
    if (code == _languageCode) return;
    _languageCode = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (code == null) {
      await prefs.remove(_keyLanguage);
    } else {
      await prefs.setString(_keyLanguage, code);
    }
  }

  // Pass null to clear the override and fall back to WhatsApp's default width.
  Future<void> setChatListWidth(double? width) async {
    if (width == _chatListWidth) return;
    _chatListWidth = width;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (width == null) {
      await prefs.remove(_keyChatListWidth);
    } else {
      await prefs.setDouble(_keyChatListWidth, width);
    }
  }

  static ThemeMode parseMode(String? name) => ThemeMode.values.firstWhere(
        (m) => m.name == name,
        orElse: () => ThemeMode.system,
      );
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

// Tries to claim the single-instance lock. Returns the bound socket on success
// (this is the first/primary copy), or null if another copy already holds it.
Future<ServerSocket?> _acquireSingleInstanceLock() async {
  try {
    return await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      _singleInstancePort,
    );
  } on SocketException {
    return null;
  }
}

// Best-effort: tell the already-running copy to bring its window to the front.
Future<void> _signalExistingInstance() async {
  try {
    final socket = await Socket.connect(
      InternetAddress.loopbackIPv4,
      _singleInstancePort,
      timeout: const Duration(seconds: 2),
    );
    socket.write('focus');
    await socket.flush();
    await socket.close();
  } catch (_) {
    // If we can't reach it, nothing more we can do — just exit.
  }
}

// Restore + focus the primary window when a second copy was launched.
Future<void> _surfaceWindow() async {
  if (await windowManager.isMinimized()) await windowManager.restore();
  if (!await windowManager.isVisible()) await windowManager.show();
  await windowManager.focus();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Refuse to start a second copy: if the lock is already held, ask the running
  // copy to surface and quit immediately.
  final lockSocket = await _acquireSingleInstanceLock();
  if (lockSocket == null) {
    await _signalExistingInstance();
    exit(0);
  }

  if (Platform.isLinux) LinuxWebViewPlatform.registerWith();
  if (Platform.isWindows) WindowsWebViewPlatform.registerWith();

  await windowManager.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final minimizeToTray = prefs.getBool(_keyMinimizeToTray) ?? false;
  final themeController = ThemeController(
    ThemeController.parseMode(prefs.getString(_keyThemeMode)),
    Color(prefs.getInt(_keySeedColor) ?? _defaultSeed.toARGB32()),
    prefs.getDouble(_keyChatListWidth),
    prefs.getString(_keyLanguage), // null = follow OS locale
  );

  await windowManager.waitUntilReadyToShow(
    WindowOptions(
      title: 'WhatsApp',
      size: const Size(1200, 800),
      minimumSize: const Size(800, 600),
      center: true,
      titleBarStyle: TitleBarStyle.normal,
    ),
    () async {
      // Prevent default close; onWindowClose() decides what to do.
      await windowManager.setPreventClose(true);
      await windowManager.show();
      await windowManager.focus();
    },
  );

  // Listen for later copies asking us to surface. Drain each connection; any
  // contact is the signal — bring the window back to the front.
  lockSocket.listen((client) {
    client.drain<void>().catchError((_) {});
    _surfaceWindow();
  });

  runApp(WhatsAppApp(
    initialMinimizeToTray: minimizeToTray,
    themeController: themeController,
  ));
}

// ---------------------------------------------------------------------------
// App root
// ---------------------------------------------------------------------------

class WhatsAppApp extends StatelessWidget {
  final bool initialMinimizeToTray;
  final ThemeController themeController;

  // Navigator key so TrayListener can pop routes when restoring from tray.
  static final navigatorKey = GlobalKey<NavigatorState>();

  const WhatsAppApp({
    super.key,
    required this.initialMinimizeToTray,
    required this.themeController,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) {
        final seed = themeController.seedColor;
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'WhatsApp',
          debugShowCheckedModeBanner: false,
          locale: themeController.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: seed),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: seed,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          themeMode: themeController.mode,
          home: WhatsAppView(
            initialMinimizeToTray: initialMinimizeToTray,
            themeController: themeController,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Main webview screen
// ---------------------------------------------------------------------------

class WhatsAppView extends StatefulWidget {
  final bool initialMinimizeToTray;
  final ThemeController themeController;

  const WhatsAppView({
    super.key,
    required this.initialMinimizeToTray,
    required this.themeController,
  });

  @override
  State<WhatsAppView> createState() => _WhatsAppViewState();
}

class _WhatsAppViewState extends State<WhatsAppView>
    with WindowListener, TrayListener, SingleTickerProviderStateMixin {
  late final WebViewController _controller;
  final _progress = ValueNotifier<int>(0);
  final _webviewBoundaryKey = GlobalKey();
  Ticker? _repaintTicker;

  late bool _minimizeToTray;
  bool _trayReady = false;
  int _trayInitAttempts = 0;
  bool _hasUnread = false;
  bool _settingsOpen = false;
  bool _openingSettings = false;
  bool _cancelOpenSettings = false;
  bool _widthInjected = false;
  double? _lastInjectedWidth;

  // ── init / dispose ────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _minimizeToTray = widget.initialMinimizeToTray;

    windowManager.addListener(this);
    // Both platforms use the native title bar, so Settings is only reachable
    // from the tray. The tray icon is therefore always shown.
    // Post-frame: AppLocalizations requires a fully mounted context.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _setupTray();
    });

    // Re-apply the chat-list width override whenever appearance settings change.
    widget.themeController.addListener(_applyChatListWidth);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_userAgent)
      ..addJavaScriptChannel(
        'WaWidthChannel',
        onMessageReceived: (msg) {
          final width = double.tryParse(msg.message);
          if (width != null &&
              width >= _minChatListWidth &&
              width <= _maxChatListWidth) {
            widget.themeController.setChatListWidth(width);
          }
        },
      )
      ..addJavaScriptChannel(
        'WaTitleChannel',
        onMessageReceived: (msg) => _onTitleChanged(msg.message),
      )
      ..addJavaScriptChannel(
        'WaExternalChannel',
        onMessageReceived: (msg) {
          final uri = Uri.tryParse(msg.message);
          if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) return;
          final url = msg.message;
          if (Platform.isLinux) Process.run('xdg-open', [url]);
          if (Platform.isWindows) Process.run('cmd', ['/c', 'start', '', url]);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => _progress.value = 0,
          onProgress: (p) => _progress.value = p,
          onPageFinished: (_) {
            _progress.value = 100;
            // The page reload wipes injected styles, so re-apply on each load.
            _applyChatListWidth();
            _injectLinkInterceptor();
            _injectTitleMonitor();
          },
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
      _repaintTicker = createTicker(_onRepaintTick)..start();
    }
  }

  @override
  void dispose() {
    _repaintTicker?.dispose();
    widget.themeController.removeListener(_applyChatListWidth);
    windowManager.removeListener(this);
    if (_trayReady) trayManager.removeListener(this);
    _progress.dispose();
    super.dispose();
  }

  // ── repaint loop (Linux only) ─────────────────────────────────────────────

  void _onRepaintTick(Duration _) {
    if (_settingsOpen) return;
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

  // Left click toggles the window. (On Windows this fires on button-up; on
  // Linux app_indicator shows the menu instead and never emits this event.)
  @override
  void onTrayIconMouseDown() => _toggleWindow();

  // Right click opens the context menu. On Windows the menu is not shown
  // automatically, so it must be popped up explicitly; on Linux app_indicator
  // already shows it on click, so this event never fires there.
  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        _restoreWindow();
        break;
      case 'reload':
        _restoreWindow();
        _controller.loadRequest(Uri.parse(_whatsAppUrl));
        break;
      case 'settings':
        _restoreWindow();
        _openSettings();
        break;
      case 'kofi':
        launchUrl(Uri.parse('https://ko-fi.com/gianluviv'));
        break;
      case 'quit':
        windowManager.destroy();
        break;
    }
  }

  Future<void> _toggleWindow() async {
    if (await windowManager.isVisible()) {
      await windowManager.hide();
    } else {
      _restoreWindow();
    }
  }

  void _restoreWindow() {
    _cancelOpenSettings = true;
    if (_settingsOpen) setState(() => _settingsOpen = false);
    WhatsAppApp.navigatorKey.currentState
        ?.popUntil((route) => route.isFirst);
    windowManager.show();
    windowManager.focus();
  }

  // ── tray setup / teardown ─────────────────────────────────────────────────

  Future<void> _setupTray() async {
    if (_trayReady) return;
    // Capture localizations before any async gap.
    final loc = AppLocalizations.of(context)!;
    try {
      // Windows loads the tray icon via LoadImage(IMAGE_ICON), which needs a
      // real .ico; Linux (WebKitGTK/AppIndicator) uses the PNG.
      await trayManager.setIcon(
        Platform.isWindows
            ? 'assets/icons/tray_icon.ico'
            : 'assets/icons/tray_icon.png',
      );
      if (Platform.isWindows) await trayManager.setToolTip('WhatsApp');
      await trayManager.setContextMenu(Menu(items: [
        MenuItem(key: 'show', label: loc.trayRestore),
        MenuItem(key: 'reload', label: loc.trayReload),
        MenuItem(key: 'settings', label: loc.traySettings),
        MenuItem.separator(),
        MenuItem(key: 'kofi', label: loc.trayKofi),
        MenuItem.separator(),
        MenuItem(key: 'quit', label: loc.trayQuit),
      ]));
      trayManager.addListener(this);
      _trayReady = true;
      _trayInitAttempts = 0;
      if (_hasUnread) _updateTrayIcon();
    } catch (e) {
      debugPrint('Tray init failed (attempt ${_trayInitAttempts + 1}): $e');
      if (_trayInitAttempts < 3) {
        _trayInitAttempts++;
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && !_trayReady) _setupTray();
        });
      }
    }
  }

  // ── settings ──────────────────────────────────────────────────────────────

  Future<void> _onMinimizeToTrayChanged(bool value) async {
    // The tray is always present; this setting only changes whether closing
    // the window hides it to the tray or quits the app.
    setState(() => _minimizeToTray = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyMinimizeToTray, value);
  }

  // ── chat-list width injection ───────────────────────────────────────────────

  // Injects (or removes) a persistent stylesheet pinning the WhatsApp chat-list
  // pane (#side) to the chosen width. A stylesheet rule with !important survives
  // WhatsApp's React re-renders, unlike inline element styles.
  Future<void> _applyChatListWidth() async {
    final width = widget.themeController.chatListWidth;
    if (_widthInjected && width == _lastInjectedWidth) return;
    _widthInjected = true;
    _lastInjectedWidth = width;
    final wExpr = width == null ? 'null' : width.round().toString();
    // Two things, both robust to WhatsApp's hashed class names:
    //  1. Width: pin the chat-list COLUMN wrapper (the element whose direct
    //     child is #side, a stable id) via :has(); the conversation is flex:1
    //     and fills the rest. A persistent stylesheet survives React re-renders.
    //  2. Separator line: WhatsApp keeps a second "ghost" column anchored at the
    //     original 40%, whose conversation draws a faint border-left
    //     (rgba(0,0,0,0.1)) — a stray grey line. We blank that border on tall
    //     panes (matched by appearance, not class) and re-apply via a
    //     MutationObserver; clearing the width restores the original borders.
    final js = '''
(function(){
  window.__waWidth = $wExpr;
  var id='wa-custom-layout', e=document.getElementById(id);
  if(window.__waWidth==null){ if(e) e.remove(); }
  else {
    if(!e){e=document.createElement('style');e.id=id;document.head.appendChild(e);}
    var w=window.__waWidth;
    e.textContent='div:has(> #side){flex:0 0 '+w+'px!important;width:'+w+'px!important;min-width:'+w+'px!important;max-width:'+w+'px!important;}';
  }
  function alpha(col){var o=col.indexOf('(');var p=col.indexOf(')');if(o<0||p<0)return 1;var a=col.substring(o+1,p).split(',');return a.length>=4?parseFloat(a[3]):1;}
  function fix(){
    var W=window.__waWidth;
    var side=document.getElementById('side');
    if(!side) return;
    var root=side.closest?side.closest('[class~="two"]'):null; root=root||document.body;
    if(W==null){
      var mod=root.querySelectorAll('[data-wa-sep]');
      for(var k=0;k<mod.length;k++){var m=mod[k];m.style.removeProperty('border-left-color');m.style.removeProperty('border-left-width');m.style.removeProperty('border-left-style');m.removeAttribute('data-wa-sep');}
      return;
    }
    // The real conversation pane = first tall sibling after the #side column.
    var wrapper=side.parentElement;
    var conv=wrapper?wrapper.nextElementSibling:null;
    while(conv && conv.getBoundingClientRect().height<400) conv=conv.nextElementSibling;
    // Blank every stray faint vertical separator (full-height panes), capturing
    // WhatsApp's own border colour so we can reuse it (stays theme-correct).
    var nodes=root.querySelectorAll('div');
    for(var i=0;i<nodes.length;i++){var n=nodes[i];
      if(n===conv || n.getAttribute('data-wa-sep')) continue;
      var c=getComputedStyle(n);var a=alpha(c.borderLeftColor);var bw=parseFloat(c.borderLeftWidth);
      if(c.borderLeftStyle!=='none' && bw>=1 && bw<=2 && a>0 && a<=0.4 && n.getBoundingClientRect().height>400){
        window.__waSepColor=c.borderLeftColor;
        n.style.setProperty('border-left-color','transparent','important');
        n.setAttribute('data-wa-sep','hidden');
      }
    }
    // Redraw the separator exactly on the new list/conversation boundary.
    if(conv){
      var col=window.__waSepColor||'rgba(0, 0, 0, 0.1)';
      conv.style.setProperty('border-left-width','1px','important');
      conv.style.setProperty('border-left-style','solid','important');
      conv.style.setProperty('border-left-color',col,'important');
      conv.setAttribute('data-wa-sep','draw');
    }
  }
  window.__waFix=fix; fix();
  if(!window.__waObs){
    window.__waObs=new MutationObserver(function(){ if(window.__waT)return; window.__waT=setTimeout(function(){window.__waT=null;window.__waFix();},400); });
    window.__waObs.observe(document.body,{childList:true,subtree:true});
  }
})();
(function(){
  var HID='wa-resize-handle', MIN=280, MAX=600;
  function posHandle(){
    var side=document.getElementById('side');
    if(!side) return;
    var r=side.getBoundingClientRect();
    if(r.width<10) return;
    var h=document.getElementById(HID);
    if(!h){
      h=document.createElement('div');
      h.id=HID;
      h.style.cssText='position:fixed;top:0;width:6px;height:100vh;cursor:col-resize;z-index:99999;background:transparent;';
      document.body.appendChild(h);
      h.addEventListener('mouseenter',function(){h.style.background='rgba(128,128,128,0.18)';});
      h.addEventListener('mouseleave',function(){h.style.background='transparent';});
      h.addEventListener('mousedown',function(ev){
        ev.preventDefault();
        var sx=ev.clientX;
        var sr=document.getElementById('side').getBoundingClientRect();
        var sw=sr.width, sl=sr.left;
        document.body.style.userSelect='none';
        document.body.style.cursor='col-resize';
        function move(e){
          var nw=Math.round(Math.max(MIN,Math.min(MAX,sw+(e.clientX-sx))));
          window.__waWidth=nw;
          var el=document.getElementById('wa-custom-layout');
          if(!el){el=document.createElement('style');el.id='wa-custom-layout';document.head.appendChild(el);}
          el.textContent='div:has(> #side){flex:0 0 '+nw+'px!important;width:'+nw+'px!important;min-width:'+nw+'px!important;max-width:'+nw+'px!important;}';
          h.style.left=(sl+nw-3)+'px';
        }
        function up(e){
          document.removeEventListener('mousemove',move);
          document.removeEventListener('mouseup',up);
          document.body.style.userSelect='';
          document.body.style.cursor='';
          var nw=Math.round(Math.max(MIN,Math.min(MAX,sw+(e.clientX-sx))));
          window.__waFix&&window.__waFix();
          if(typeof WaWidthChannel!=='undefined') WaWidthChannel.postMessage(String(nw));
        }
        document.addEventListener('mousemove',move);
        document.addEventListener('mouseup',up);
      });
      window.addEventListener('resize',function(){setTimeout(posHandle,50);});
    }
    h.style.left=(r.right-3)+'px';
  }
  window.__waPosHandle=posHandle;
  // Hook __waFix at IIFE level (not inside if(!h)) so the MutationObserver
  // repositions the handle after every React re-render, including the very
  // first render when #side appears after page load.
  if(!window.__waPosHandleHooked){
    var origFix=window.__waFix;
    window.__waFix=function(){origFix&&origFix();posHandle();};
    window.__waPosHandleHooked=true;
  }
  if(document.getElementById('side')){
    if(window.__waWidth==null) setTimeout(posHandle,100); else posHandle();
  } else {
    setTimeout(posHandle,1000);
  }
})();
''';
    try {
      await _controller.runJavaScript(js);
    } catch (_) {
      // Webview not ready yet; onPageFinished will re-apply.
    }
  }

  // Intercepts window.open() and target="_blank" clicks.
  // External URLs (not whatsapp.com / whatsapp.net) are forwarded to the OS
  // default browser via WaExternalChannel. All other window.open() calls
  // return null — no popup webview is ever created inside the app window,
  // which also prevents WhatsApp's multi-window detection dialog.
  Future<void> _injectLinkInterceptor() async {
    const js = '''
(function(){
  if(window.__waLinkHandler){
    document.removeEventListener('click', window.__waLinkHandler, true);
    window.__waLinkHandler = null;
  }
  function isExternal(url){
    try { var h=new URL(url).hostname; return !h.endsWith('whatsapp.com')&&!h.endsWith('whatsapp.net'); }
    catch(e){ return false; }
  }
  window.open = function(url, target, features){
    if(url && url !== '' && url !== 'about:blank' && isExternal(url)){
      if(typeof WaExternalChannel !== 'undefined') WaExternalChannel.postMessage(url);
    }
    return null;
  };
  window.__waLinkHandler = function(e){
    var a = e.target.closest ? e.target.closest('a[target="_blank"]') : null;
    if(!a || !a.href) return;
    e.preventDefault();
    e.stopPropagation();
    if(isExternal(a.href)){
      if(typeof WaExternalChannel !== 'undefined') WaExternalChannel.postMessage(a.href);
    }
  };
  document.addEventListener('click', window.__waLinkHandler, true);
})();
''';
    try {
      await _controller.runJavaScript(js);
    } catch (_) {}
  }

  // Reads WhatsApp's current chat-list width from the DOM, used as the slider's
  // starting point. Returns null if #side is absent (e.g. logged out).
  Future<double?> _measureChatListWidth() async {
    try {
      final r = await _controller.runJavaScriptReturningResult(
        "(function(){var s=document.querySelector('#side');"
        "return s?Math.round(s.getBoundingClientRect().width):0;})()",
      );
      final v = double.tryParse(r.toString());
      return (v != null && v > 0) ? v : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _openSettings() async {
    if (_openingSettings) return;
    _openingSettings = true;
    _cancelOpenSettings = false;
    try {
      final defaultWidth = await _measureChatListWidth() ?? _fallbackChatListWidth;
      if (!mounted || _cancelOpenSettings) return;
      setState(() => _settingsOpen = true);
      await Navigator.of(context).push(PageRouteBuilder<void>(
        opaque: true,
        pageBuilder: (_, _, _) => SettingsScreen(
          minimizeToTray: _minimizeToTray,
          onMinimizeToTrayChanged: _onMinimizeToTrayChanged,
          themeController: widget.themeController,
          defaultChatListWidth: defaultWidth,
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ));
      if (mounted) setState(() => _settingsOpen = false);
    } finally {
      _openingSettings = false;
    }
  }

  // ── unread badge ──────────────────────────────────────────────────────────

  void _onTitleChanged(String title) {
    // WhatsApp Web sets the title to "(N) WhatsApp" when there are N unread messages.
    final hasUnread = RegExp(r'^\(\d+\)').hasMatch(title);
    if (hasUnread == _hasUnread) return;
    _hasUnread = hasUnread;
    if (_trayReady) _updateTrayIcon();
  }

  Future<void> _updateTrayIcon() async {
    final icon = _hasUnread
        ? (Platform.isWindows
            ? 'assets/icons/tray_icon_unread.ico'
            : 'assets/icons/tray_icon_unread.png')
        : (Platform.isWindows
            ? 'assets/icons/tray_icon.ico'
            : 'assets/icons/tray_icon.png');
    try {
      await trayManager.setIcon(icon);
    } catch (e) {
      debugPrint('Tray icon update failed: $e');
    }
  }

  Future<void> _injectTitleMonitor() async {
    const js = '''
(function(){
  if (window.__waTitleObs) return;
  function sendTitle() {
    if (typeof WaTitleChannel !== 'undefined') {
      WaTitleChannel.postMessage(document.title || '');
    }
  }
  function attach(el) {
    window.__waTitleObs = new MutationObserver(sendTitle);
    window.__waTitleObs.observe(el, {childList:true,characterData:true,subtree:true});
    sendTitle();
  }
  var titleEl = document.querySelector('title');
  if (titleEl) {
    attach(titleEl);
  } else {
    var t = setInterval(function(){
      var el = document.querySelector('title');
      if (el) { clearInterval(t); attach(el); }
    }, 500);
  }
})();
''';
    try {
      await _controller.runJavaScript(js);
    } catch (_) {}
  }

  // ── build ─────────────────────────────────────────────────────────────────

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
                color: Theme.of(context).colorScheme.primary,
              );
            },
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
  final ThemeController themeController;
  // WhatsApp's current pane width, used as the slider's start when there is no
  // override yet.
  final double defaultChatListWidth;

  const SettingsScreen({
    super.key,
    required this.minimizeToTray,
    required this.onMinimizeToTrayChanged,
    required this.themeController,
    required this.defaultChatListWidth,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _minimizeToTray;
  // Local copy for smooth dragging; committed to the controller on release.
  late double? _chatListWidth;

  @override
  void initState() {
    super.initState();
    _minimizeToTray = widget.minimizeToTray;
    _chatListWidth = widget.themeController.chatListWidth;
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.themeController;
    return Scaffold(
      // Standard AppBar; its automatic leading button returns to the webview.
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SectionHeader(AppLocalizations.of(context)!.sectionBehavior),
          _SettingsTile(
            icon: Icons.logout,
            title: AppLocalizations.of(context)!.minimizeToTrayTitle,
            subtitle: AppLocalizations.of(context)!.minimizeToTraySubtitle,
            trailing: Switch.adaptive(
              value: _minimizeToTray,
              onChanged: (v) {
                setState(() => _minimizeToTray = v);
                widget.onMinimizeToTrayChanged(v);
              },
            ),
          ),
          _SectionHeader(AppLocalizations.of(context)!.sectionAppearance),
          // Rebuilds when the user changes theme mode / accent color.
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) => Column(
              children: [
                _SettingsCard(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CardTitle(icon: Icons.brightness_6_outlined, title: AppLocalizations.of(context)!.themeTitle),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<ThemeMode>(
                            segments: [
                              ButtonSegment(
                                value: ThemeMode.system,
                                icon: Icon(Icons.brightness_auto),
                                label: Text(AppLocalizations.of(context)!.themeSystem),
                              ),
                              ButtonSegment(
                                value: ThemeMode.light,
                                icon: Icon(Icons.light_mode_outlined),
                                label: Text(AppLocalizations.of(context)!.themeLight),
                              ),
                              ButtonSegment(
                                value: ThemeMode.dark,
                                icon: Icon(Icons.dark_mode_outlined),
                                label: Text(AppLocalizations.of(context)!.themeDark),
                              ),
                            ],
                            selected: {controller.mode},
                            onSelectionChanged: (s) => controller.setMode(s.first),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _SettingsCard(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CardTitle(
                          icon: Icons.palette_outlined,
                          title: AppLocalizations.of(context)!.primaryColorTitle,
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: [
                            for (final color in _seedColorChoices)
                              _ColorDot(
                                color: color,
                                selected: controller.seedColor.toARGB32() ==
                                    color.toARGB32(),
                                onTap: () => controller.setSeedColor(color),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                _SettingsCard(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CardTitle(
                          icon: Icons.language_outlined,
                          title: AppLocalizations.of(context)!.languageTitle,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: DropdownButton<String?>(
                            value: controller.languageCode,
                            isExpanded: true,
                            underline: const SizedBox.shrink(),
                            items: [
                              DropdownMenuItem(
                                value: null,
                                child: Text(AppLocalizations.of(context)!.languageSystem),
                              ),
                              for (final locale in AppLocalizations.supportedLocales)
                                if (_localeDisplayNames.containsKey(locale.languageCode))
                                  DropdownMenuItem(
                                    value: locale.languageCode,
                                    child: Text(_localeDisplayNames[locale.languageCode]!),
                                  ),
                            ],
                            onChanged: (v) => controller.setLanguage(v),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _SectionHeader(AppLocalizations.of(context)!.sectionLayout),
          _SettingsCard(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _CardTitle(
                        icon: Icons.view_column_outlined,
                        title: AppLocalizations.of(context)!.chatListWidthTitle,
                      ),
                      const Spacer(),
                      Text(
                        _chatListWidth == null
                            ? AppLocalizations.of(context)!.chatListWidthDefault
                            : '${_chatListWidth!.round()} px',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    min: _minChatListWidth,
                    max: _maxChatListWidth,
                    value: (_chatListWidth ?? widget.defaultChatListWidth)
                        .clamp(_minChatListWidth, _maxChatListWidth)
                        .toDouble(),
                    onChanged: (v) => setState(() => _chatListWidth = v),
                    onChangeEnd: (v) => controller.setChatListWidth(v),
                  ),
                  if (_chatListWidth != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          setState(() => _chatListWidth = null);
                          controller.setChatListWidth(null);
                        },
                        child: Text(AppLocalizations.of(context)!.resetToDefault),
                      ),
                    ),
                ],
              ),
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
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// Rounded surface used as the container for each settings entry.
class _SettingsCard extends StatelessWidget {
  final Widget child;
  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}

// Leading icon + title used at the top of the appearance cards.
class _CardTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _CardTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, color: scheme.onSurfaceVariant, size: 22),
        const SizedBox(width: 16),
        Text(title,
            style: TextStyle(color: scheme.onSurface, fontSize: 14)),
      ],
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.onSurface
                : Colors.transparent,
            width: 3,
          ),
        ),
        child:
            selected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
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
    final scheme = Theme.of(context).colorScheme;
    return _SettingsCard(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(icon, color: scheme.onSurfaceVariant, size: 22),
        title: Text(title,
            style: TextStyle(color: scheme.onSurface, fontSize: 14)),
        subtitle: Text(subtitle,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
        trailing: trailing,
      ),
    );
  }
}
