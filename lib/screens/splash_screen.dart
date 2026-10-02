import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../assets.dart';
import '../game/gleam_settings.dart';
import '../orbit/core/relay_models.dart';
import '../orbit/orbit_router.dart';
import '../orbit/pages/no_signal_page.dart';
import '../orbit/pages/notify_gate.dart';
import '../orbit/pages/portal_view.dart';
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
  double _progress = 0;
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
      _stop = const NativeStop();
      return;
    }
    try {
      _stop = await router.decide(onProgress: (_) {});
    } catch (_) {
      _stop = const NativeStop();
    }
    if (mounted) _enter();
  }

  Future<void> _load() async {
    final started = DateTime.now();
    final assets = GleamAssets.preload;
    for (var i = 0; i < assets.length; i++) {
      if (!mounted) return;
      await precacheImage(AssetImage(assets[i]), context);
      if (!mounted) return;
      setState(() => _progress = (i + 1) / assets.length);
    }
    await GleamSettings.instance.load();
    final elapsed = DateTime.now().difference(started);
    const minimum = Duration(milliseconds: 1200);
    if (elapsed < minimum) {
      await Future<void>.delayed(minimum - elapsed);
    }
    if (!mounted) return;
    _assetsReady = true;
    _enter();
  }

  Future<void> _enter() async {
    // Route only once both the loading work and the routing decision finish.
    if (_entering || !_assetsReady || _stop == null) return;
    _entering = true;
    final stop = _stop!;
    final router = widget.router;

    if (stop is PortalStop && router != null) {
      await _openPortal(stop, router);
      return;
    }
    if (stop is OfflineStop && router != null) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => NoSignalPage(
            sensor: router.sensor,
            retryBuilder: (_) => SplashScreen(router: router),
          ),
        ),
      );
      return;
    }

    // NativeStop / gate disabled → the white slot game.
    try {
      await SystemChrome.setPreferredOrientations(gameOrientations);
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const MainMenuScreen()),
    );
  }

  Future<void> _openPortal(PortalStop stop, OrbitRouter router) async {
    Widget portalBuilder(BuildContext _) => PortalView(
      url: stop.url,
      coldLaunch: stop.coldLaunch,
      vault: router.vault,
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
        Text(
          'LOADING',
          style: cinzel(14, GleamColors.goldLight, letterSpacing: 3),
        ),
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
                  child: FractionallySizedBox(
                    widthFactor: _progress.clamp(0.04, 1),
                    heightFactor: 1,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [GleamColors.goldDeep, GleamColors.goldLight],
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
