import 'dart:async';

import 'package:flutter/material.dart';

import '../audio/sound.dart';
import '../game/native_math.dart';
import '../game/progress.dart';
import '../game/world_data.dart';
import '../theme/neon_theme.dart';
import '../widgets/backdrop.dart';
import '../widgets/design_scale.dart';
import '../widgets/diorama.dart';
import '../widgets/neon_ui.dart';
import '../widgets/orb_view.dart';
import '../widgets/routes.dart';
import '../widgets/story_dialogs.dart';
import 'puzzle_screen.dart';
import 'world_map_screen.dart';

/// Shown after a puzzle: the object comes back to life and rewards are listed.
class RestoreScreen extends StatefulWidget {
  const RestoreScreen({super.key, required this.applied});

  final Applied applied;

  @override
  State<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends State<RestoreScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  final List<Timer> _timers = [];

  Applied get a => widget.applied;
  RegionDef get region => regionDefs[a.spec.region];
  int get level => a.spec.level;

  @override
  void initState() {
    super.initState();
    _c.forward();
    final sound = Sound.instance;
    _timers.add(
      Timer(const Duration(milliseconds: 650), () => sound.play(Sfx.restore)),
    );
    for (var i = 0; i < a.reward.stars; i++) {
      _timers.add(
        Timer(
          Duration(milliseconds: 1250 + 330 * i),
          () => sound.play(Sfx.success, volume: 0.8),
        ),
      );
    }
    if (a.newOrbs.isNotEmpty || a.decor != null) {
      _timers.add(
        Timer(const Duration(milliseconds: 2300), () => sound.play(Sfx.reward)),
      );
    }
    if (a.regionDone) {
      _timers.add(
        Timer(const Duration(milliseconds: 2900), () {
          if (!mounted) return;
          sound.play(Sfx.areaUnlock);
          showMemoryDialog(context, region);
        }),
      );
    }
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _c.dispose();
    super.dispose();
  }

  Animation<double> _slice(
    double a,
    double b, [
    Curve curve = Curves.easeOutCubic,
  ]) => CurvedAnimation(
    parent: _c,
    curve: Interval(a, b, curve: curve),
  );

  void _next() {
    if (level < Progress.levels - 1) {
      Navigator.of(context).pushReplacement(
        softRoute(PuzzleScreen(region: a.spec.region, level: level + 1)),
      );
    } else {
      _toMap();
    }
  }

  void _toMap() {
    final nav = Navigator.of(context);
    nav.popUntil((r) => r.isFirst);
    nav.push(softRoute(const WorldMapScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final progress = Progress.instance;
    final slot = region.slots[level];
    final reward = a.reward;
    final last = level >= Progress.levels - 1;
    return NeonScaffold(
      background: Backdrop(
        asset: region.background,
        accent: region.accent,
        dim: 0.28,
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 14),
            FadeTransition(
              opacity: _slice(0.0, 0.2),
              child: Column(
                children: [
                  Text(
                    a.firstClear ? 'MEMORY RESTORED' : 'MEMORY REPLAYED',
                    style: oxa(
                      25,
                      weight: 800,
                      letterSpacing: 4.4,
                      shadows: glowText(region.accent),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    slot.name.toUpperCase(),
                    style: oxa(
                      13,
                      color: region.accent,
                      weight: 700,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: RegionDiorama(
                    region: region,
                    restoredMask: progress.restoredMask(region.index),
                    decorMask: progress.decorMask(region.index),
                    reveal: a.firstClear ? level : null,
                    aspect: 1.05,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _resultPanel(reward),
            ),
            if (a.newOrbs.isNotEmpty || a.decor != null) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FadeTransition(
                  opacity: _slice(0.7, 0.95),
                  child: _rewardRow(),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: FadeTransition(
                opacity: _slice(0.78, 1),
                child: Column(
                  children: [
                    NeonButton(
                      label: last ? 'WORLD MAP' : 'NEXT LEVEL',
                      accent: region.accent,
                      accent2: region.accent2,
                      icon: last
                          ? Icons.public_rounded
                          : Icons.arrow_forward_rounded,
                      onTap: _next,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: NeonButton(
                            label: 'LEVELS',
                            filled: false,
                            height: 46,
                            fontSize: 14,
                            accent: region.accent,
                            onTap: () => Navigator.of(context).pop(),
                            sound: Sfx.close,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: NeonButton(
                            label: 'REPLAY',
                            filled: false,
                            height: 46,
                            fontSize: 14,
                            accent: Neon.violet,
                            onTap: () => Navigator.of(context).pushReplacement(
                              softRoute(
                                PuzzleScreen(
                                  region: a.spec.region,
                                  level: level,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultPanel(RewardSpec reward) {
    return HoloPanel(
      accent: region.accent,
      accent2: region.accent2,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 3; i++)
                      _AnimatedStar(
                        on: i < reward.stars,
                        delay: _slice(
                          0.45 + 0.14 * i,
                          0.58 + 0.14 * i,
                          Curves.elasticOut,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (reward.firstTry) _tag('FLAWLESS', Neon.mint),
                    if (reward.fast) _tag('SWIFT', Neon.cyan),
                    if (reward.aids == 0 &&
                        !reward.firstTry &&
                        reward.mistakes <= 1)
                      _tag('CLEAN', Neon.violet),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ENERGY',
                style: oxa(
                  10.5,
                  color: Neon.dim,
                  weight: 700,
                  letterSpacing: 2.4,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final v = (reward.energy * _slice(0.5, 0.85).value).round();
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.bolt_rounded,
                        color: Neon.gold,
                        size: 26,
                      ),
                      Text(
                        '+${formatCount(v)}',
                        style: oxa(
                          28,
                          color: Neon.gold,
                          weight: 800,
                          shadows: glowText(Neon.gold, blur: 10),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tag(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: ShapeDecoration(
      color: color.withValues(alpha: 0.15),
      shape: BeveledRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: color.withValues(alpha: 0.8)),
      ),
    ),
    child: Text(
      text,
      style: oxa(10.5, color: color, weight: 800, letterSpacing: 1.6),
    ),
  );

  Widget _rewardRow() {
    final decor = a.decor;
    final compact = a.newOrbs.length + (decor == null ? 0 : 1) > 2;
    return HoloPanel(
      accent: Neon.gold,
      accent2: Neon.pink,
      cut: 12,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Text(
            'NEW',
            style: oxa(11, color: Neon.gold, weight: 800, letterSpacing: 2.6),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 58,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final id in a.newOrbs)
                    GestureDetector(
                      onTap: () =>
                          showOrbDialog(context, orbDefs[id], found: true),
                      child: Padding(
                        padding: EdgeInsets.only(right: compact ? 8 : 14),
                        child: Row(
                          children: [
                            OrbView(def: orbDefs[id], size: 44, halo: 0.3),
                            if (!compact) const SizedBox(width: 8),
                            if (!compact)
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    orbDefs[id].name
                                        .split(' ')
                                        .first
                                        .toUpperCase(),
                                    style: oxa(
                                      13,
                                      weight: 800,
                                      letterSpacing: 1.4,
                                    ),
                                  ),
                                  Text(
                                    'ORB',
                                    style: oxa(
                                      10,
                                      color: orbDefs[id].glow,
                                      weight: 800,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  if (decor != null)
                    Row(
                      children: [
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: Image.asset(
                            regionDefs[decor.$1].decor[decor.$2].sprite.path,
                            fit: BoxFit.contain,
                          ),
                        ),
                        if (!compact) const SizedBox(width: 8),
                        if (!compact)
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                regionDefs[decor.$1].decor[decor.$2].name
                                    .toUpperCase(),
                                style: oxa(12, weight: 800, letterSpacing: 1),
                              ),
                              Text(
                                'DECOR',
                                style: oxa(
                                  10,
                                  color: Neon.pink,
                                  weight: 800,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                      ],
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

class _AnimatedStar extends StatelessWidget {
  const _AnimatedStar({required this.on, required this.delay});

  final bool on;
  final Animation<double> delay;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: delay,
      builder: (context, _) {
        final v = delay.value.clamp(0.0, 1.4);
        return Transform.scale(
          scale: on ? 0.4 + 0.6 * v : 1,
          child: Icon(
            Icons.star_rounded,
            size: 42,
            color: on && v > 0.05
                ? Neon.gold
                : Neon.faint.withValues(alpha: 0.5),
            shadows: on && v > 0.05
                ? [
                    Shadow(
                      color: Neon.gold.withValues(alpha: 0.85),
                      blurRadius: 18,
                    ),
                  ]
                : null,
          ),
        );
      },
    );
  }
}
