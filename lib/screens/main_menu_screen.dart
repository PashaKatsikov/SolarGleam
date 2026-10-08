import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../assets.dart';
import '../audio/sound.dart';
import '../game/progress.dart';
import '../game/world_data.dart';
import '../theme/gleam_theme.dart';
import '../theme/neon_theme.dart';
import '../widgets/backdrop.dart';
import '../widgets/design_scale.dart';
import '../widgets/image_slice.dart';
import '../widgets/loading_backdrop.dart';
import '../widgets/neon_ui.dart';
import '../widgets/orb_view.dart';
import '../widgets/routes.dart';
import 'collection_screen.dart';
import 'puzzle_screen.dart';
import 'settings_screen.dart';
import 'world_map_screen.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> with SingleTickerProviderStateMixin {
  static const _logoSource = Size(512, 512);
  static const _logoRect = Rect.fromLTWH(9, 159, 494, 199);

  late final AnimationController _orbit = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 22),
  )..repeat();

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    Sound.instance.startAmbient();
  }

  @override
  void dispose() {
    _orbit.dispose();
    super.dispose();
  }

  int get _scene {
    final progress = Progress.instance;
    var best = 0;
    for (final r in progress.openRegions) {
      if (r > best) best = r;
    }
    return best;
  }

  void _play() {
    final next = Progress.instance.nextLevel;
    Sound.instance.play(Sfx.teleport, volume: 0.6);
    if (next == null) {
      Navigator.of(context).push(softRoute(const WorldMapScreen()));
    } else {
      Navigator.of(context).push(softRoute(PuzzleScreen(region: next.$1, level: next.$2)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.orientationOf(context) == Orientation.landscape) {
      return const Scaffold(backgroundColor: GleamColors.night, body: LoadingBackdrop());
    }
    return ListenableBuilder(
      listenable: Progress.instance,
      builder: (context, _) {
        final progress = Progress.instance;
        final region = regionDefs[_scene];
        final next = progress.nextLevel;
        final started = progress.totalCleared > 0;
        return NeonScaffold(
          background: Backdrop(asset: region.background, accent: region.accent, dim: 0.22),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'RESTORED ${progress.totalCleared} / ${Progress.regions * Progress.levels}',
                              style: oxa(11.5, weight: 800, letterSpacing: 2.2),
                            ),
                            const SizedBox(height: 6),
                            RailBar(value: progress.worldPercent, color: region.accent, height: 6),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      EnergyChip(value: progress.energy),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 330,
                  height: 330 * (199 / 494),
                  child: const ImageSlice(
                    asset: GleamAssets.gameName,
                    source: _logoSource,
                    rect: _logoRect,
                  ),
                ),
                Expanded(child: _hero(region)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
                  child: Column(
                    children: [
                      NeonButton(
                        label: started ? 'CONTINUE' : 'PLAY',
                        height: 62,
                        fontSize: 21,
                        accent: region.accent,
                        accent2: region.accent2,
                        icon: Icons.play_arrow_rounded,
                        onTap: _play,
                        sound: null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        next == null
                            ? 'EVERY MEMORY IS RESTORED'
                            : '${regionDefs[next.$1].name}  ·  LEVEL ${next.$2 + 1}',
                        style: oxa(11, color: Neon.dim, weight: 700, letterSpacing: 2.2),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: NeonButton(
                              label: 'WORLDS',
                              filled: false,
                              height: 50,
                              fontSize: 14,
                              accent: Neon.cyan,
                              icon: Icons.public_rounded,
                              onTap: () => Navigator.of(context).push(softRoute(const WorldMapScreen())),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: NeonButton(
                              label: 'COLLECTION',
                              filled: false,
                              height: 50,
                              fontSize: 14,
                              accent: Neon.mint,
                              icon: Icons.blur_circular_rounded,
                              onTap: () => Navigator.of(context).push(softRoute(const CollectionScreen())),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      NeonButton(
                        label: 'SETTINGS',
                        filled: false,
                        height: 46,
                        fontSize: 14,
                        accent: Neon.violet,
                        icon: Icons.tune_rounded,
                        onTap: () => Navigator.of(context).push(softRoute(const SettingsScreen())),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The core with orbs circling it.
  Widget _hero(RegionDef region) {
    const ids = [0, 1, 2, 4, 6, 3];
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        final coreSize = math.min(w * 0.46, h * 0.82);
        final orbSize = coreSize * 0.36;
        return AnimatedBuilder(
          animation: _orbit,
          builder: (context, _) {
            final entries = <(double, Widget)>[];
            for (var i = 0; i < ids.length; i++) {
              final a = (_orbit.value + i / ids.length) * math.pi * 2;
              final depth = math.sin(a); // -1 back .. 1 front
              final rx = w * 0.36;
              final ry = h * 0.2;
              final x = w / 2 + math.cos(a) * rx;
              final y = h * 0.55 + depth * ry - math.sin(a * 2) * 4;
              final scale = 0.74 + 0.26 * (depth + 1) / 2;
              final size = orbSize * scale;
              entries.add((
                depth,
                Positioned(
                  left: x - size / 2,
                  top: y - size / 2,
                  width: size,
                  height: size,
                  child: OrbView(
                    def: orbDefs[ids[i]],
                    size: size,
                    dim: (1 - depth) * 0.22,
                    lit: (math.sin(a * 3 + i) * 0.5 + 0.5) * 0.12,
                  ),
                ),
              ));
            }
            entries.sort((a, b) => a.$1.compareTo(b.$1));
            final back = entries.where((e) => e.$1 < 0);
            final front = entries.where((e) => e.$1 >= 0);
            final bob = math.sin(_orbit.value * math.pi * 2 * 4) * 4;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: w / 2 - coreSize * 0.7,
                  top: h * 0.55 + coreSize * 0.18,
                  width: coreSize * 1.4,
                  height: coreSize * 0.5,
                  child: Image.asset(
                    region.platform.path,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                for (final e in back) e.$2,
                Positioned(
                  left: w / 2 - coreSize / 2,
                  top: h * 0.55 - coreSize / 2 + bob,
                  width: coreSize,
                  height: coreSize,
                  child: Image.asset(
                    Art.sprite('core', 0),
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                for (final e in front) e.$2,
              ],
            );
          },
        );
      },
    );
  }
}
