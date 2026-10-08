import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../assets.dart';
import '../audio/sound.dart';
import '../game/world_data.dart';
import '../theme/neon_theme.dart';
import 'design_scale.dart';
import 'neon_ui.dart';
import 'orb_view.dart';

/// Shows the explanation card for one rule. Resolves when the player closes it.
Future<void> showRuleTutorial(BuildContext context, int bit, {bool first = false}) async {
  Sound.instance.play(Sfx.open);
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, a, b) => DesignScale(child: _TutorialCard(bit: bit, first: first)),
    transitionBuilder: (context, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: Tween<double>(begin: 0.9, end: 1).animate(curved), child: child),
      );
    },
  );
}

class _TutorialCard extends StatelessWidget {
  const _TutorialCard({required this.bit, required this.first});

  final int bit;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final info = ruleInfo(bit);
    final color = ruleColor(bit);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Material(
          color: Colors.transparent,
          child: HoloPanel(
            accent: color,
            accent2: Neon.violet,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            fillAlpha: 0.94,
            strong: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  first ? 'HOW TO RESTORE' : 'NEW RULE',
                  style: oxa(11.5, color: Neon.dim, weight: 700, letterSpacing: 3),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(ruleIcon(bit), color: color, size: 26),
                    const SizedBox(width: 10),
                    Text(
                      info.name,
                      style: oxa(28, weight: 800, letterSpacing: 4, shadows: glowText(color)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(info.line, style: oxa(14, color: color, weight: 600, letterSpacing: 1)),
                const SizedBox(height: 14),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color.withValues(alpha: 0.28)),
                  ),
                  child: SizedBox(height: 150, child: RuleDemo(bit: bit)),
                ),
                const SizedBox(height: 14),
                Text(
                  info.how,
                  textAlign: TextAlign.center,
                  style: oxa(14.5, color: Neon.text.withValues(alpha: 0.92), weight: 500, height: 1.4),
                ),
                const SizedBox(height: 18),
                NeonButton(
                  label: 'GOT IT',
                  accent: color,
                  onTap: () => Navigator.of(context).pop(),
                  sound: Sfx.close,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Beat {
  const _Beat(this.start, this.end, this.orb, {this.ghost = false});

  final double start;
  final double end;
  final int orb;
  final bool ghost;
}

/// A looping mini scene that shows one rule: watch first, then answer.
class RuleDemo extends StatefulWidget {
  const RuleDemo({super.key, required this.bit});

  final int bit;

  @override
  State<RuleDemo> createState() => _RuleDemoState();
}

class _RuleDemoState extends State<RuleDemo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  List<_Beat> get _preview => switch (widget.bit) {
    Rule.ghost => const [_Beat(.05, .13, 0), _Beat(.17, .25, 2, ghost: true), _Beat(.29, .37, 1)],
    Rule.shift => const [_Beat(.05, .13, 0)],
    Rule.glyph => const [],
    _ => const [_Beat(.05, .13, 0), _Beat(.17, .25, 1), _Beat(.29, .37, 2)],
  };

  List<_Beat> get _answer => switch (widget.bit) {
    Rule.mirror => const [_Beat(.62, .70, 2), _Beat(.73, .81, 1), _Beat(.84, .92, 0)],
    Rule.ghost => const [_Beat(.62, .70, 0), _Beat(.76, .84, 1)],
    Rule.shift => const [_Beat(.80, .90, 0)],
    Rule.glyph => const [_Beat(.74, .84, 1)],
    _ => const [_Beat(.62, .70, 0), _Beat(.73, .81, 1), _Beat(.84, .92, 2)],
  };

  double _pulse(double t, _Beat b) {
    if (t < b.start || t > b.end) return 0;
    final k = (t - b.start) / (b.end - b.start);
    return math.sin(k * math.pi).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            final h = box.maxHeight;
            const size = 54.0;
            final base = [w * 0.2, w * 0.5, w * 0.8];
            final xs = [...base];
            if (widget.bit == Rule.shift) {
              final k = Curves.easeInOutCubic.transform(((t - 0.42) / 0.14).clamp(0.0, 1.0));
              xs[0] = base[0] + (base[2] - base[0]) * k;
              xs[2] = base[2] + (base[0] - base[2]) * k;
            }
            final glyphMode = widget.bit == Rule.glyph;
            final cy = h * (glyphMode ? 0.66 : 0.5);

            final lit = [0.0, 0.0, 0.0];
            final ghostFlag = [false, false, false];
            for (final b in _preview) {
              final p = _pulse(t, b);
              if (p > 0) {
                lit[b.orb] = math.max(lit[b.orb], p);
                ghostFlag[b.orb] = b.ghost;
              }
            }
            for (final b in _answer) {
              lit[b.orb] = math.max(lit[b.orb], _pulse(t, b));
            }

            // numbers shown under the orbs while the preview plays
            final tags = <int, String>{};
            if (!glyphMode && t < 0.58) {
              var n = 0;
              for (final b in _preview) {
                if (t >= b.start) {
                  tags[b.orb] = b.ghost ? 'X' : '${++n}';
                } else if (!b.ghost) {
                  n++;
                }
              }
            }
            if (widget.bit == Rule.mirror && t > 0.4 && t < 0.6) {
              tags
                ..clear()
                ..addAll({0: '3', 1: '2', 2: '1'});
            }

            final answering = t >= 0.55;
            _Beat? tapping;
            for (final b in _answer) {
              if (t >= b.start - 0.04 && t <= b.end + 0.02) tapping = b;
            }

            // glyph token on the core
            int? token;
            if (glyphMode && t > 0.08 && t < 0.34) token = 1;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 8,
                  child: Center(
                    child: Text(
                      answering ? 'YOUR TURN' : 'WATCH',
                      style: oxa(
                        11,
                        color: answering ? Neon.mint : Neon.cyan,
                        weight: 800,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                ),
                if (glyphMode)
                  Positioned(
                    left: w / 2 - 28,
                    top: 24,
                    width: 56,
                    height: 56,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.asset(Art.sprite('core', 0), fit: BoxFit.contain),
                        if (token != null)
                          Image.asset(Art.sprite('symbols', token), width: 34, height: 34),
                      ],
                    ),
                  ),
                for (var i = 0; i < 3; i++)
                  Positioned(
                    left: xs[i] - size / 2,
                    top: cy - size / 2 + (glyphMode ? 8 : 4),
                    width: size,
                    height: size,
                    child: OrbView(
                      def: orbDefs[const [0, 1, 2][i]],
                      size: size,
                      lit: lit[i],
                      ghost: ghostFlag[i],
                      glyph: glyphMode ? i : null,
                      dim: (!answering && t > 0.02 && lit[i] == 0 && widget.bit != Rule.shift) ? 0.7 : 0,
                    ),
                  ),
                for (final entry in tags.entries)
                  Positioned(
                    left: xs[entry.key] - 12,
                    top: cy + size / 2 + 8,
                    width: 24,
                    height: 20,
                    child: Center(
                      child: Text(
                        entry.value,
                        style: oxa(
                          14,
                          color: entry.value == 'X' ? Neon.red : Neon.gold,
                          weight: 800,
                        ),
                      ),
                    ),
                  ),
                if (tapping != null)
                  Positioned(
                    left: xs[tapping.orb] - 4,
                    top: cy + 8 + (_pulse(t, tapping) * -6),
                    child: Icon(
                      Icons.touch_app_rounded,
                      size: 34,
                      color: Colors.white.withValues(alpha: 0.95),
                      shadows: const [Shadow(color: Neon.cyan, blurRadius: 12)],
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
