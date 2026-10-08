import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../assets.dart';
import '../game/game_settings.dart';
import '../game/native_math.dart';
import '../game/progress.dart';
import '../theme/gleam_theme.dart';
import '../widgets/loading_backdrop.dart';
import 'main_menu_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _progress = 0;
  var _entering = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
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
    await GameSettings.instance.load();
    await Progress.instance.load();
    NativeMath.instance;
    final elapsed = DateTime.now().difference(started);
    const minimum = Duration(milliseconds: 1200);
    if (elapsed < minimum) {
      await Future<void>.delayed(minimum - elapsed);
    }
    if (!mounted) return;
    await _enter();
  }

  Future<void> _enter() async {
    if (_entering) return;
    _entering = true;
    try {
      await SystemChrome.setPreferredOrientations(gameOrientations);
    } catch (_) {
      // Orientation locks are unavailable outside a device shell.
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const MainMenuScreen()),
    );
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
