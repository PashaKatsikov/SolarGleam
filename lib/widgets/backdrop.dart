import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/game_settings.dart';
import '../theme/neon_theme.dart';

/// Full-screen scene art with grading, glow and drifting light motes.
class Backdrop extends StatelessWidget {
  const Backdrop({
    super.key,
    required this.asset,
    this.accent = Neon.cyan,
    this.dim = 0.3,
    this.alignment = Alignment.center,
    this.particles = true,
    this.bottomShade = 0.55,
  });

  final String asset;
  final Color accent;
  final double dim;
  final Alignment alignment;
  final bool particles;
  final double bottomShade;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Neon.void0),
        RepaintBoundary(
          child: Image.asset(
            asset,
            fit: BoxFit.cover,
            alignment: alignment,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Neon.void0.withValues(alpha: dim + 0.2),
                Neon.void0.withValues(alpha: dim * 0.4),
                Neon.void0.withValues(alpha: dim * 0.7),
                Neon.void0.withValues(alpha: dim + bottomShade),
              ],
              stops: const [0, 0.3, 0.62, 1],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, 0.1),
              radius: 0.95,
              colors: [accent.withValues(alpha: 0.13), Colors.transparent],
            ),
          ),
        ),
        if (particles) AmbientParticles(color: accent),
        const _Vignette(),
      ],
    );
  }
}

class _Vignette extends StatelessWidget {
  const _Vignette();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            radius: 1.25,
            colors: [Colors.transparent, Neon.void0.withValues(alpha: 0.55)],
            stops: const [0.62, 1],
          ),
        ),
      ),
    );
  }
}

class AmbientParticles extends StatefulWidget {
  const AmbientParticles({super.key, required this.color, this.seed = 7});

  final Color color;
  final int seed;

  @override
  State<AmbientParticles> createState() => _AmbientParticlesState();
}

class _AmbientParticlesState extends State<AmbientParticles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 120),
  )..repeat();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: GameSettings.instance,
      builder: (context, _) {
        final count = GameSettings.instance.particleBudget;
        if (count == 0) return const SizedBox.shrink();
        return IgnorePointer(
          child: RepaintBoundary(
            child: CustomPaint(
              size: Size.infinite,
              painter: _MotePainter(_clock, widget.color, widget.seed, count),
            ),
          ),
        );
      },
    );
  }
}

class _MotePainter extends CustomPainter {
  _MotePainter(this.clock, this.color, this.seed, this.count) : super(repaint: clock);

  final Animation<double> clock;
  final Color color;
  final int seed;
  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value * 120;
    final rng = math.Random(seed);
    final paint = Paint();
    for (var i = 0; i < count; i++) {
      final x0 = rng.nextDouble();
      final y0 = rng.nextDouble();
      final speed = 0.006 + rng.nextDouble() * 0.014;
      final phase = rng.nextDouble() * math.pi * 2;
      final radius = 0.8 + rng.nextDouble() * 2.2;
      final sway = 6 + rng.nextDouble() * 14;
      final y = (y0 - speed * t) % 1.0;
      final x = x0 * size.width + math.sin(t * 0.4 + phase) * sway;
      final twinkle = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(t * 1.3 + phase));
      paint.color = Color.lerp(color, Colors.white, 0.55)!.withValues(alpha: 0.55 * twinkle);
      canvas.drawCircle(Offset(x, y * size.height), radius, paint);
      if (radius > 2.2) {
        paint.color = color.withValues(alpha: 0.12 * twinkle);
        canvas.drawCircle(Offset(x, y * size.height), radius * 3.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_MotePainter old) =>
      old.color != color || old.count != count || old.seed != seed;
}
