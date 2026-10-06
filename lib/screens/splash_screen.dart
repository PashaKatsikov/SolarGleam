import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../assets.dart';
import '../game/gleam_settings.dart';
import '../orbit/core/flow_models.dart';
import '../orbit/orbit_router.dart';
import '../orbit/pages/no_signal_page.dart';
import '../orbit/pages/notify_gate.dart';
import '../orbit/pages/web_page.dart';
import '../theme/gleam_theme.dart';
import '../widgets/loading_backdrop.dart';
import 'main_menu_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.router});

  final OrbitRouter? router;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // The bar fills to at most 90% from real loading checkpoints and only hits
  // 100% in `_enter`, immediately before the app is actually launched.
  static const _assetWeight = 0.4;
  static const _routeWeight = 0.5;
  static const _loadCeiling = _assetWeight + _routeWeight; // 0.90

  double _progress = 0;
  double _assetProgress = 0;
  double _routeProgress = 0;
  var _entering = false;
  GleamStop? _stop;
  bool _assetsReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _resolveStop();
  }

  Future<void> _resolveStop() async {
    final router = widget.router;
    if (router == null) {
      // Nothing to route, so that checkpoint is already done.
      _routeProgress = 1;
      _stop = const NativeStop();
      _recompute();
      _maybeEnter();
      return;
    }
    try {
      _stop = await router.decide(onProgress: _onRouteProgress);
    } catch (_) {
      _stop = const NativeStop();
    }
    _maybeEnter();
  }

  void _onRouteProgress(double value) {
    _routeProgress = value.clamp(0.0, 1.0);
    _recompute();
  }

  void _recompute() {
    if (!mounted || _entering) return;
    final combined =
        (_assetProgress * _assetWeight + _routeProgress * _routeWeight)
            .clamp(0.0, _loadCeiling);
    if (combined != _progress) setState(() => _progress = combined);
  }

  Future<void> _load() async {
    final started = DateTime.now();
    final assets = GleamAssets.preload;
    for (var i = 0; i < assets.length; i++) {
      if (!mounted) return;
      await precacheImage(AssetImage(assets[i]), context);
      if (!mounted) return;
      _assetProgress = (i + 1) / assets.length;
      _recompute();
    }
    await GleamSettings.instance.load();
    // A short floor so the fill animation is visible — but only on the paths
    // that actually show the loading screen (offline bails out before this).
    final elapsed = DateTime.now().difference(started);
    const minimum = Duration(milliseconds: 1200);
    if (elapsed < minimum) {
      await Future<void>.delayed(minimum - elapsed);
    }
    if (!mounted) return;
    _assetsReady = true;
    _assetProgress = 1;
    _recompute();
    _maybeEnter();
  }

  /// Decides whether we can leave the splash yet. Offline takes a shortcut:
  /// it must not show the loading screen or let the progress bar fill, so it
  /// never waits for asset preloading.
  void _maybeEnter() {
    final stop = _stop;
    if (_entering || stop == null) return;

    if (stop is OfflineStop && widget.router != null) {
      _entering = true;
      _goOffline(widget.router!);
      return;
    }

    if (!_assetsReady) return;
    _entering = true;
    _enter(stop);
  }

  Future<void> _goOffline(OrbitRouter router) async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => NoSignalPage(
          sensor: router.sensor,
          retryBuilder: (_) => SplashScreen(router: router),
        ),
      ),
    );
  }

  Future<void> _enter(GleamStop stop) async {
    final router = widget.router;

    // Fill to 100% right before the real launch, then let the bar settle.
    if (mounted) setState(() => _progress = 1);
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;

    if (stop is WebStop && router != null) {
      await _openPortal(stop, router);
      return;
    }

    // NativeStop / disabled → the native game.
    try {
      await SystemChrome.setPreferredOrientations(gameOrientations);
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const MainMenuScreen()),
    );
  }

  Future<void> _openPortal(WebStop stop, OrbitRouter router) async {
    Widget portalBuilder(BuildContext _) => WebPage(
      url: stop.url,
      coldLaunch: stop.coldLaunch,
      sensor: router.sensor,
      push: router.push,
      agent: router.agent,
    );

    if (router.vault.shouldShowPushInvite &&
        await router.push.canOfferPermission()) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => NotifyGate(
            vault: router.vault,
            push: router.push,
            nextBuilder: portalBuilder,
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute<void>(builder: portalBuilder));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GleamColors.night,
      body: LoadingBackdrop(
        child: SafeArea(
          child: Align(
            alignment: const Alignment(0, 0.82),
            child: _progressBar(),
          ),
        ),
      ),
    );
  }

  Widget _progressBar() {
    final width = MediaQuery.sizeOf(context).shortestSide * 0.46;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _LoadingLabel(),
        const SizedBox(height: 10),
        SizedBox(
          width: width,
          height: 7,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Color(0xCC120C08)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: 0,
                      end: _progress.clamp(0.04, 1),
                    ),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    builder: (context, value, _) => FractionallySizedBox(
                      widthFactor: value,
                      heightFactor: 1,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              GleamColors.goldDeep,
                              GleamColors.goldLight,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// "LOADING" with three dots that fill in and reset on a loop.
class _LoadingLabel extends StatefulWidget {
  const _LoadingLabel();

  @override
  State<_LoadingLabel> createState() => _LoadingLabelState();
}

class _LoadingLabelState extends State<_LoadingLabel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = cinzel(14, GleamColors.goldLight, letterSpacing: 3);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // 0 → 1 → 2 → 3 lit dots, cycling.
        final lit = (_controller.value * 4).floor().clamp(0, 3);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('LOADING', style: style),
            for (var i = 0; i < 3; i++)
              Opacity(
                opacity: i < lit ? 1 : 0.2,
                child: Text('.', style: style),
              ),
          ],
        );
      },
    );
  }
}
