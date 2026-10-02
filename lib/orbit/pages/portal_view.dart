import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../net/gleam_vault.dart';
import '../net/push_beacon.dart';
import '../net/reach_sensor.dart';
import '../net/solar_agent.dart';
import 'no_signal_page.dart';

/// Full-screen WebView shell for the gray flow. Navigations are gated by
/// scheme only (never by host — the relay may hand back a different partner
/// host after release). All page tweaks ship as ONE merged JS bundle.
class PortalView extends StatefulWidget {
  const PortalView({
    super.key,
    required this.url,
    required this.vault,
    required this.sensor,
    required this.push,
    required this.agent,
    this.coldLaunch = false,
  });

  final String url;
  final GleamVault vault;
  final ReachSensor sensor;
  final PushBeacon push;
  final SolarAgent agent;
  final bool coldLaunch;

  @override
  State<PortalView> createState() => _PortalViewState();
}

class _PortalViewState extends State<PortalView> with WidgetsBindingObserver {
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
    _enterImmersive();
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    final params = Platform.isIOS
        ? WebKitWebViewControllerCreationParams(
            // Inline playback handled natively → no JS media injection.
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumePending());
  }

  void _enterImmersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _settleColdViewport() async {
    _enterImmersive();
    // Settle in the ACTUAL orientation before mounting (no rotation nudge).
    // Cold-viewport settle delay rotated per project (360 ms).
    await Future<void>.delayed(const Duration(milliseconds: 360));
    if (!mounted) return;
    setState(() => _viewportReady = true);
    await _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    setState(() {});
    final view = View.of(context);
    final size = view.physicalSize;
    final rotated = _lastMetricsSize != null &&
        ((_lastMetricsSize!.width < _lastMetricsSize!.height) !=
            (size.width < size.height));
    _lastMetricsSize = size;
    if (!rotated) return;
    _enterImmersive();
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
      _installPageTweaks();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _enterImmersive();
      _consumePending();
    }
  }

  Future<void> _consumePending() async {
    final value = await widget.vault.consumePushUrl();
    final uri = value == null ? null : Uri.tryParse(value);
    if (mounted && uri != null && uri.hasScheme) {
      await _controller.loadRequest(uri);
    }
  }

  NavigationDelegate _navigation() {
    return NavigationDelegate(
      onPageStarted: (url) {
        _lastMainUrl = url;
      },
      onPageFinished: (_) {
        _redirectAttempts = 0;
        _installPageTweaks();
        // Post-load resize + inset re-assert, delay rotated per project.
        Future<void>.delayed(const Duration(milliseconds: 1050), () async {
          if (!mounted) return;
          setState(() {});
          await _controller.runJavaScript(
            'window.dispatchEvent(new Event("resize"));'
            'window.visualViewport?.dispatchEvent(new Event("resize"));',
          );
          _installPageTweaks();
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
        // Redirect-loop retries rotated per project (2).
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
        // Drop javascript: and other unknown schemes; hand off real app
        // schemes (tel/mailto/etc.) to the system.
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
          retryBuilder: (_) => PortalView(
            url: current,
            vault: widget.vault,
            sensor: widget.sensor,
            push: widget.push,
            agent: widget.agent,
          ),
        ),
      ),
    );
  }

  /// Single merged bundle of all page tweaks (safe-area vars, zoom lock,
  /// tap polish, keyboard lift, focus scale), guarded by one sentinel.
  void _installPageTweaks() {
    _controller.runJavaScript(r'''
(() => {
  var root = window;
  if (root.__sgReady) { if (root.__sgRefresh) root.__sgRefresh(); return; }
  root.__sgReady = true;

  var MARK = 'sg-sheet';
  var cssVars = [
    ':root{',
    '--safe-area-inset-top:0px!important;',
    '--safe-area-inset-right:0px!important;',
    '--safe-area-inset-bottom:0px!important;',
    '--safe-area-inset-left:0px!important;',
    '--sat:0px!important;--sar:0px!important;',
    '--sab:0px!important;--sal:0px!important;',
    '--safe-top:0px!important;--safe-right:0px!important;',
    '--safe-bottom:0px!important;--safe-left:0px!important;',
    '}',
    '.gameview-mobile-header,.app-header,.js-safe-top{',
    'padding-top:0!important;margin-top:0!important;}',
    'html,body{overscroll-behavior:none!important;',
    'overscroll-behavior-y:none!important;}',
    '*{-webkit-tap-highlight-color:transparent!important;}',
    '*:not(input):not(textarea):not([contenteditable="true"]){',
    '-webkit-touch-callout:none!important;}',
    'input,textarea,select,[contenteditable="true"]{',
    'font-size:max(16px,1em)!important;}'
  ].join('');

  var keyboardOpen = function() {
    var v = root.visualViewport;
    return !!v && v.height < root.innerHeight * 0.75;
  };

  var lockViewport = function() {
    var host = document.head || document.documentElement;
    if (!host) return;
    var vp = document.querySelector('meta[name="viewport"]');
    if (!vp) { vp = document.createElement('meta');
      vp.setAttribute('name', 'viewport'); host.appendChild(vp); }
    vp.setAttribute('content',
      'width=device-width, initial-scale=1.0, maximum-scale=1.0, ' +
      'minimum-scale=1.0, user-scalable=no, viewport-fit=contain');
  };

  var applyCss = function() {
    if (keyboardOpen()) return;
    var host = document.head || document.documentElement;
    if (!host) return;
    var sheet = document.getElementById(MARK);
    if (!sheet) { sheet = document.createElement('style');
      sheet.id = MARK; host.appendChild(sheet); }
    sheet.textContent = cssVars;
  };

  root.__sgRefresh = function() { lockViewport(); applyCss(); };

  // Zoom gestures off.
  var stop = function(e) { e.preventDefault(); };
  ['gesturestart', 'gesturechange', 'gestureend'].forEach(function(t) {
    document.addEventListener(t, stop, {passive: false});
  });
  document.addEventListener('touchmove', function(e) {
    if (e.scale !== undefined && e.scale !== 1) e.preventDefault();
  }, {passive: false});
  var lastTap = 0;
  document.addEventListener('touchend', function(e) {
    var now = Date.now();
    if (now - lastTap <= 300) e.preventDefault();
    lastTap = now;
  }, {passive: false});

  // Keyboard lift.
  var editable = function(n) { return !!n && n.matches &&
    n.matches('input, textarea, select, [contenteditable="true"]'); };
  document.addEventListener('focusin', function(e) {
    if (editable(e.target)) root.setTimeout(function() {
      var a = document.activeElement;
      if (editable(a)) a.scrollIntoView({behavior: 'auto', block: 'nearest'});
    }, 350);
  }, true);

  // Re-assert on SPA route changes.
  ['pushState', 'replaceState'].forEach(function(name) {
    var orig = history[name];
    history[name] = function() {
      var r = orig.apply(this, arguments);
      root.setTimeout(root.__sgRefresh, 150);
      return r;
    };
  });
  root.addEventListener('popstate', function() {
    root.setTimeout(root.__sgRefresh, 150);
  });

  root.__sgRefresh();
  root.setInterval(applyCss, 2900);
})();
''');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _metricsDebounce?.cancel();
    _networkSubscription?.cancel();
    widget.push.onDestination = null;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.of(context).viewPadding;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && await _controller.canGoBack()) {
          await _controller.goBack();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: _viewportReady
            ? Padding(
                padding: EdgeInsets.only(
                  top: safe.top,
                  bottom: safe.bottom,
                  left: safe.left,
                  right: safe.right,
                ),
                child: WebViewWidget(controller: _controller),
              )
            : const ColoredBox(color: Colors.black),
      ),
    );
  }
}
