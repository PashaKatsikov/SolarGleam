import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../assets.dart';
import '../game/world_data.dart';
import '../theme/neon_theme.dart';

const _ghostGlow = Color(0xFFB9C4E8);

const _ghostMatrix = <double>[
  0.30, 0.45, 0.25, 0, 38,
  0.30, 0.45, 0.25, 0, 44,
  0.30, 0.45, 0.25, 0, 64,
  0, 0, 0, 1, 0,
];

/// One neon orb: sprite, halo, optional inner glyph badge and hint ring.
class OrbView extends StatelessWidget {
  const OrbView({
    super.key,
    required this.def,
    required this.size,
    this.lit = 0,
    this.ghost = false,
    this.dim = 0,
    this.glyph,
    this.hint = 0,
    this.halo = 0.12,
    this.shake = 0,
  });

  final OrbDef def;
  final double size;

  /// 0..1 flash strength.
  final double lit;
  final bool ghost;

  /// 0..1 how far the orb is darkened (resting during the preview).
  final double dim;
  final int? glyph;

  /// 0..1 pulse of the hint ring, 0 hides it.
  final double hint;
  final double halo;

  /// 0..1 wobble after a wrong tap.
  final double shake;

  @override
  Widget build(BuildContext context) {
    final glow = ghost ? _ghostGlow : def.glow;
    final boost = lit.clamp(0.0, 1.0);
    final overlayWhite = Colors.white.withValues(alpha: 0.5 * boost);
    final overlayDark = const Color(0xFF02030A).withValues(alpha: 0.58 * dim * (1 - boost));

    ColorFilter? filter;
    if (ghost && boost > 0.02) {
      filter = const ColorFilter.matrix(_ghostMatrix);
    } else if (boost > 0.02) {
      filter = ColorFilter.mode(overlayWhite, BlendMode.srcATop);
    } else if (dim > 0.02) {
      filter = ColorFilter.mode(overlayDark, BlendMode.srcATop);
    }

    Widget sprite = Image.asset(
      def.sprite.path,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
    );
    if (filter != null) sprite = ColorFiltered(colorFilter: filter, child: sprite);

    final dx = shake == 0 ? 0.0 : math.sin(shake * math.pi * 7) * (1 - shake) * size * 0.12;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // halo
          Positioned(
            left: -size * 0.5,
            top: -size * 0.5,
            width: size * 2,
            height: size * 2,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      glow.withValues(alpha: (halo + 0.62 * boost).clamp(0.0, 1.0)),
                      glow.withValues(alpha: 0),
                    ],
                    stops: const [0.18, 1],
                  ),
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(dx, 0),
            child: Transform.scale(scale: 1 + 0.13 * boost, child: sprite),
          ),
          if (ghost && boost > 0.02)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _GlitchPainter(boost)),
              ),
            ),
          if (glyph != null)
            Center(
              child: Container(
                width: size * 0.52,
                height: size * 0.52,
                padding: EdgeInsets.all(size * 0.05),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF050818).withValues(alpha: 0.72),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.75), width: 1.2),
                  boxShadow: [BoxShadow(color: glow.withValues(alpha: 0.7), blurRadius: size * 0.2)],
                ),
                child: Image.asset(
                  Art.sprite('symbols', glyph!),
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          if (hint > 0)
            Positioned(
              left: -size * 0.12 - size * 0.08 * hint,
              top: -size * 0.12 - size * 0.08 * hint,
              right: -size * 0.12 - size * 0.08 * hint,
              bottom: -size * 0.12 - size * 0.08 * hint,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.95 - 0.5 * hint),
                      width: 2.4,
                    ),
                    boxShadow: [BoxShadow(color: Neon.cyan.withValues(alpha: 0.8), blurRadius: 14)],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GlitchPainter extends CustomPainter {
  const _GlitchPainter(this.strength);

  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random((strength * 1000).round());
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.5 * strength);
    for (var i = 0; i < 6; i++) {
      final y = rng.nextDouble() * size.height;
      final w = size.width * (0.35 + rng.nextDouble() * 0.6);
      final x = (size.width - w) / 2 + (rng.nextDouble() - 0.5) * size.width * 0.2;
      canvas.drawRect(Rect.fromLTWH(x, y, w, 1.6), paint);
    }
    canvas.drawCircle(
      size.center(Offset.zero),
      size.width * 0.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFFFF5470).withValues(alpha: 0.6 * strength),
    );
  }

  @override
  bool shouldRepaint(_GlitchPainter old) => old.strength != strength;
}
