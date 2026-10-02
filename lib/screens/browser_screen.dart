import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key, required this.title, required this.url});

  final String title;
  final String url;

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  late final WebViewController _controller;
  var _progress = 0;
  var _failed = false;
  var _canGoBack = false;

  @override
  void initState() {
    super.initState();
    final params = WebKitWebViewControllerCreationParams(
      allowsInlineMediaPlayback: true,
    );
    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..setUserAgent(_safariUserAgent())
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
          onPageStarted: (_) {
            if (mounted) setState(() => _failed = false);
          },
          onPageFinished: (_) => _syncNavigation(),
          onWebResourceError: (error) {
            if (error.isForMainFrame == false) return;
            if (mounted) setState(() => _failed = true);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));

    final platform = _controller.platform;
    if (platform is WebKitWebViewController) {
      platform.setAllowsBackForwardNavigationGestures(true);
    }
  }

  Future<void> _syncNavigation() async {
    final back = await _controller.canGoBack();
    if (!mounted) return;
    setState(() {
      _canGoBack = back;
      _failed = false;
      _progress = 100;
    });
  }

  String _safariUserAgent() {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final logical = view.physicalSize / view.devicePixelRatio;
    final tablet = logical.shortestSide >= 600;
    final match = RegExp(r'(\d+)\.(\d+)')
        .firstMatch(Platform.operatingSystemVersion);
    final major = match?.group(1) ?? '18';
    final minor = match?.group(2) ?? '0';
    if (tablet) {
      return 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/$major.$minor Safari/605.1.15';
    }
    return 'Mozilla/5.0 (iPhone; CPU iPhone OS ${major}_$minor like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/$major.$minor Mobile/15E148 Safari/604.1';
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: const Color(0xFFF8F8F8),
        border: const Border(
          bottom: BorderSide(color: Color(0x33000000), width: 0.5),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
        middle: Text(widget.title),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _canGoBack ? () => _controller.goBack() : null,
              child: const Icon(CupertinoIcons.back),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _controller.reload(),
              child: const Icon(CupertinoIcons.refresh),
            ),
          ],
        ),
      ),
      child: Column(
        children: [
          if (_progress < 100)
            LinearProgressIndicator(
              value: _progress == 0 ? null : _progress / 100,
              minHeight: 2,
              color: const Color(0xFF0A84FF),
              backgroundColor: const Color(0xFFE5E5EA),
            ),
          Expanded(
            child: SafeArea(
              top: false,
              child: Stack(
                children: [
                  WebViewWidget(controller: _controller),
                  if (_failed)
                    ColoredBox(
                      color: const Color(0xFFFFFFFF),
                      child: Center(
                        child: CupertinoButton(
                          onPressed: () {
                            setState(() => _failed = false);
                            _controller.loadRequest(Uri.parse(widget.url));
                          },
                          child: const Text(
                            'Could not open the page. Try again.',
                          ),
                        ),
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
