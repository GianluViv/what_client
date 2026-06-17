import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_all/webview_all.dart';

void main() {
  runApp(const LinuxExampleApp());
}

class LinuxExampleApp extends StatelessWidget {
  const LinuxExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'webview_all_linux Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: const LinuxExamplePage(),
    );
  }
}

class LinuxExamplePage extends StatefulWidget {
  const LinuxExamplePage({super.key});

  @override
  State<LinuxExamplePage> createState() => _LinuxExamplePageState();
}

class _LinuxExamplePageState extends State<LinuxExamplePage> {
  late final WebViewController _controller;
  int _progress = 0;
  String _url = 'https://flutter.dev';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();

    if (!kIsWeb) {
      _controller
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (int progress) {
              if (mounted) {
                setState(() {
                  _progress = progress;
                });
              }
            },
            onPageStarted: (String url) {
              if (mounted) {
                setState(() {
                  _url = url;
                });
              }
              debugPrint('Loading $url');
            },
            onPageFinished: (String url) {
              if (mounted) {
                setState(() {
                  _progress = 100;
                  _url = url;
                });
              }
              debugPrint('Finished $url');
            },
            onWebResourceError: (WebResourceError error) {
              debugPrint('Error ${error.errorCode}: ${error.description}');
            },
          ),
        );
    }

    _controller.loadRequest(Uri.parse(_url));
  }

  Future<void> _load(String url) async {
    setState(() {
      _progress = 0;
      _url = url;
    });
    await _controller.loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('webview_all_linux'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: () => _load('https://flutter.dev'),
          ),
          IconButton(
            icon: const Icon(Icons.article_outlined),
            onPressed: () => _load('https://docs.flutter.dev'),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (await _controller.canGoBack()) {
                await _controller.goBack();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: () async {
              if (await _controller.canGoForward()) {
                await _controller.goForward();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _controller.reload,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Column(
            children: <Widget>[
              if (!kIsWeb && _progress < 100)
                LinearProgressIndicator(value: _progress / 100)
              else
                const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
