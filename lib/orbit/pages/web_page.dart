import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../config/orbit_config.dart';
import '../net/push_agent.dart';
import '../net/reach_sensor.dart';
import '../net/solar_agent.dart';
import 'no_signal_page.dart';

/// Full-screen WKWebView shell with no browser chrome: the web content fills
/// the screen and only the device safe-area insets show as plain black.
/// Navigations are gated by scheme only, not by host.
///
/// The User-Agent and the page-tweak scripts come from [OrbitConfig], so no
/// such literal ships in the Dart binary.
class WebPage extends StatefulWidget {
  const WebPage({
    super.key,
    required this.url,
    required this.sensor,
    required this.push,
    required this.agent,
    this.coldLaunch = false,
  });

  final String url;
  final ReachSensor sensor;
  final PushAgent push;
  final SolarAgent agent;
  final bool coldLaunch;

  @override
  State<WebPage> createState() => _WebPageState();
}

class _WebPageState extends State<WebPage> with WidgetsBindingObserver {
  late final WebViewController _controller;
  StreamSubscription<List<ConnectivityResult>>? _networkSubscription;
  bool _viewportReady = false;
  bool _coldReloadIssued = false;
  bool _offlineShown = false;
  int _redirectAttempts = 0;
  String? _lastMainUrl;
  Timer? _metricsDebounce;
  Size? _lastMetricsSize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _hideTopBar();
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    final params = Platform.isIOS
        ? WebKitWebViewControllerCreationParams(
            allowsInlineMediaPlayback: true,
            mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
          )
        : const PlatformWebViewControllerCreationParams();
    _controller =
        WebViewController.fromPlatformCreationParams(
            params,
            onPermissionRequest: (request) => request.grant(),
          )
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(Colors.black)
          ..setUserAgent(widget.agent.userAgent)
          ..enableZoom(false)
          ..setNavigationDelegate(_navigation());
    if (_controller.platform is WebKitWebViewController) {
      (_controller.platform as WebKitWebViewController)
          .setAllowsBackForwardNavigationGestures(true);
    }

    // A tapped push notification loads straight into THIS web view. The URL is
    // never persisted — it only lives for the duration of this load request.
    widget.push.onDestination = (url) {
      final uri = Uri.tryParse(url);
      if (mounted && uri != null && uri.hasScheme) {
        _controller.loadRequest(uri);
      }
    };
    _networkSubscription = widget.sensor.changes.listen((states) {
      if (states.every((state) => state == ConnectivityResult.none)) {
        _goOffline();
      }
    });

    if (widget.coldLaunch) {
      _settleColdViewport();
    } else {
      _viewportReady = true;
      _controller.loadRequest(Uri.parse(widget.url));
    }
  }

  Future<void> _settleColdViewport() async {
    // Settle in the ACTUAL orientation before mounting the web view.
    await Future<void>.delayed(const Duration(milliseconds: 360));
    if (!mounted) return;
    setState(() => _viewportReady = true);
    await _controller.loadRequest(Uri.parse(widget.url));
  }

  /// Hides the top system HUD (status bar) so only the clean black safe-area
  /// shows above the web content. The notch still reserves its inset, so the
  /// black top band stays — just without the clock / battery overlay. The
  /// bottom overlay (home indicator) is kept.
  void _hideTopBar() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: const <SystemUiOverlay>[SystemUiOverlay.bottom],
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // iOS can restore the status bar when returning from background.
    if (state == AppLifecycleState.resumed) _hideTopBar();
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    _hideTopBar();
    setState(() {});
    final view = View.of(context);
    final size = view.physicalSize;
    final rotated = _lastMetricsSize != null &&
        ((_lastMetricsSize!.width < _lastMetricsSize!.height) !=
            (size.width < size.height));
    _lastMetricsSize = size;
    if (!rotated) return;
    _metricsDebounce?.cancel();
    _pokeReflow(const <int>[60, 220, 430, 680, 980]);
  }

  void _pokeReflow(List<int> delaysMs) {
    for (final ms in delaysMs) {
      Timer(Duration(milliseconds: ms), () {
        if (!mounted) return;
        _controller.runJavaScript(
          'window.dispatchEvent(new Event("orientationchange"));'
          'window.dispatchEvent(new Event("resize"));'
          'if(window.visualViewport)'
          '  window.visualViewport.dispatchEvent(new Event("resize"));',
        ).catchError((_) {});
      });
    }
    _metricsDebounce = Timer(const Duration(milliseconds: 340), () {
      if (!mounted) return;
      _installInsetGuard();
      _installZoomLock();
    });
  }

  NavigationDelegate _navigation() {
    return NavigationDelegate(
      onPageStarted: (url) {
        _lastMainUrl = url;
      },
      onPageFinished: (_) {
        _redirectAttempts = 0;
        _installAll();
        Future<void>.delayed(const Duration(milliseconds: 800), () async {
          if (!mounted) return;
          setState(() {});
          await _controller.runJavaScript(
            'window.dispatchEvent(new Event("resize"));'
            'window.visualViewport?.dispatchEvent(new Event("resize"));',
          );
          _installInsetGuard();
          if (widget.coldLaunch && !_coldReloadIssued) {
            _coldReloadIssued = true;
            await _controller.reload();
          }
        });
      },
      onWebResourceError: (error) {
        // -999 = cancelled (a new navigation superseded this one).
        if (error.errorCode == -999) return;
        final mainFrame = error.isForMainFrame ?? true;
        final lower = error.description.toLowerCase();
        final redirectLoop = error.errorCode == -1007 ||
            lower.contains('too_many_redirects') ||
            lower.contains('too many redirects');
        if (redirectLoop && _lastMainUrl != null && _redirectAttempts < 2) {
          _redirectAttempts++;
          _controller.loadRequest(Uri.parse(_lastMainUrl!));
          return;
        }
        if (!mainFrame) return;
        _showOfflineAfterProbe();
      },
      onNavigationRequest: (request) {
        final uri = Uri.tryParse(request.url);
        if (uri == null) return NavigationDecision.prevent;
        // Scheme gate only — NO host allowlist.
        if (<String>{'http', 'https', 'about', 'data', 'blob'}
            .contains(uri.scheme)) {
          if (request.isMainFrame) _lastMainUrl = request.url;
          return NavigationDecision.navigate;
        }
        // Drop javascript: and hand real app schemes (tel/mailto/…) to the OS.
        if (uri.scheme == 'javascript') return NavigationDecision.prevent;
        launchUrl(uri, mode: LaunchMode.externalApplication);
        return NavigationDecision.prevent;
      },
    );
  }

  Future<void> _showOfflineAfterProbe() async {
    if (_offlineShown) return;
    bool online = true;
    try {
      online = await widget.sensor.canReachNetwork();
    } catch (_) {
      online = false;
    }
    if (online) return;
    _goOffline();
  }

  Future<void> _goOffline() async {
    if (_offlineShown || !mounted) return;
    _offlineShown = true;
    String current;
    try {
      current = await _controller.currentUrl() ?? widget.url;
    } catch (_) {
      current = widget.url;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => NoSignalPage(
          sensor: widget.sensor,
          retryBuilder: (_) => WebPage(
            url: current,
            sensor: widget.sensor,
            push: widget.push,
            agent: widget.agent,
          ),
        ),
      ),
    );
  }

  // Page tweaks are applied as separate, independently-guarded injections (one
  // per concern), matching the approach that keeps keyboard content-reveal
  // smooth. Each script is decrypted out of the Rust core, never a Dart literal.
  void _run(String js) {
    if (js.isEmpty) return;
    _controller.runJavaScript(js).catchError((_) {});
  }

  void _installInsetGuard() => _run(OrbitConfig.webInsetGuard);

  void _installZoomLock() => _run(OrbitConfig.webZoomLock);

  void _installTapPolish() => _run(OrbitConfig.webTapPolish);

  /// Lifts a focused field into view when the keyboard opens.
  void _installKeyboardLift() => _run(OrbitConfig.webKeyboardLift);

  /// Keeps inputs at >=16px so iOS does not zoom (and shove layout) on focus.
  void _installFocusScaleGuard() {
    if (!Platform.isIOS) return;
    _run(OrbitConfig.webFocusScale);
  }

  void _installInlinePlayback() => _run(OrbitConfig.webInlineMedia);

  void _installAll() {
    _installInsetGuard();
    _installZoomLock();
    _installTapPolish();
    _installKeyboardLift();
    _installFocusScaleGuard();
    _installInlinePlayback();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _metricsDebounce?.cancel();
    _networkSubscription?.cancel();
    widget.push.onDestination = null;
    // Restore the system bars for the native game / menu.
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Black scaffold + SafeArea → the web content fills the safe area and the
    // insets (status bar / home indicator / notch) stay plain black. No chrome.
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: _viewportReady
            ? WebViewWidget(controller: _controller)
            : const ColoredBox(color: Colors.black),
      ),
    );
  }
}
