import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../assets.dart';
import '../game/board_layout.dart';
import '../game/puzzle_controller.dart';
import '../game/world_data.dart';
import 'orb_view.dart';

/// Board height as a share of its width.
const boardAspect = 0.78;

/// Platform, core and the ring of orbs for one puzzle.
class PuzzleBoard extends StatefulWidget {
  const PuzzleBoard({super.key, required this.controller, required this.region});

  final PuzzleController controller;
  final RegionDef region;

  @override
  State<PuzzleBoard> createState() => _PuzzleBoardState();
}

class _PuzzleBoardState extends State<PuzzleBoard> with SingleTickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = math.min(c.maxWidth, c.maxHeight / boardAspect);
        final h = w * boardAspect;
        return Center(
          child: SizedBox(
            width: w,
            height: h,
            child: ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) => _content(w, h),
            ),
          ),
        );
      },
    );
  }

  Widget _content(double w, double h) {
    final ctrl = widget.controller;
    final region = widget.region;
    final n = ctrl.spec.orbs.length;
    final poses = BoardLayout.poses(n);
    final size = BoardLayout.orbSize(n) * w;
    final centre = Offset(w / 2, h * 0.5 + w * 0.025);

    final order = List.generate(n, (i) => i)
      ..sort((a, b) => poses[ctrl.slotOf[a]].y.compareTo(poses[ctrl.slotOf[b]].y));

    final coreBase = centre.dy + w * 0.07;
    final coreW = w * 0.25;
    final coreH = coreW / 0.6;

    Widget orb(int i) {
      final pose = poses[ctrl.slotOf[i]];
      final scale = BoardLayout.depthScale(pose.y);
      final d = size * scale;
      final cx = centre.dx + pose.x * w;
      final cy = centre.dy + pose.y * w;
      final tap = d * 1.2;
      final spec = ctrl.spec.orbs[i];
      final glyphMode = ctrl.spec.modes & Rule.glyph != 0;
      return AnimatedPositioned(
        key: ValueKey('orb$i'),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutCubic,
        left: cx - tap / 2,
        top: cy - tap / 2,
        width: tap,
        height: tap,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => ctrl.tapOrb(i),
          child: Center(
            child: ValueListenableBuilder<int>(
              valueListenable: ctrl.frame,
              builder: (context, _, _) => AnimatedBuilder(
                animation: _idle,
                builder: (context, _) {
                  final bob = math.sin(_idle.value * math.pi * 2 + i * 1.3) * d * 0.025;
                  final lit = ctrl.litOf(i);
                  final resting = ctrl.phase == PuzzlePhase.watching ? 0.85 : 0.0;
                  return Transform.translate(
                    offset: Offset(0, bob),
                    child: OrbView(
                      def: orbDefs[spec.kind],
                      size: d,
                      lit: lit,
                      ghost: ctrl.ghostOf(i),
                      dim: resting * (1 - lit),
                      glyph: glyphMode ? spec.glyph : null,
                      hint: ctrl.hintOf(i),
                      shake: ctrl.shakeOf(i),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
    }

    final behind = <Widget>[];
    final front = <Widget>[];
    for (final i in order) {
      final y = poses[ctrl.slotOf[i]].y;
      (y * w < coreBase - centre.dy - w * 0.02 ? behind : front).add(orb(i));
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // platform
        Positioned(
          left: 0,
          width: w,
          top: centre.dy - w * 0.37,
          height: w * 0.74,
          child: Image.asset(
            region.platform.path,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
        ),
        // platform glow
        Positioned(
          left: w * 0.06,
          width: w * 0.88,
          top: centre.dy - w * 0.2,
          height: w * 0.5,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [region.accent.withValues(alpha: 0.2), Colors.transparent],
                ),
              ),
            ),
          ),
        ),
        ...behind,
        Positioned(
          left: centre.dx - coreW / 2,
          top: coreBase - coreH,
          width: coreW,
          height: coreH,
          child: IgnorePointer(child: _Core(controller: ctrl, accent: region.accent, idle: _idle)),
        ),
        ...front,
        // glyph token above the core
        Positioned(
          left: centre.dx - w * 0.14,
          top: coreBase - coreH - w * 0.1,
          width: w * 0.28,
          height: w * 0.28,
          child: IgnorePointer(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: ctrl.tokenGlyph == null
                  ? const SizedBox.shrink(key: ValueKey('none'))
                  : _GlyphToken(
                      key: ValueKey('glyph${ctrl.tokenGlyph}'),
                      glyph: ctrl.tokenGlyph!,
                      accent: region.accent,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlyphToken extends StatelessWidget {
  const _GlyphToken({super.key, required this.glyph, required this.accent});

  final int glyph;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [accent.withValues(alpha: 0.55), accent.withValues(alpha: 0)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Image.asset(
          Art.sprite('symbols', glyph),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}

class _Core extends StatelessWidget {
  const _Core({required this.controller, required this.accent, required this.idle});

  final PuzzleController controller;
  final Color accent;
  final Animation<double> idle;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: controller.frame,
      builder: (context, _, _) => AnimatedBuilder(
        animation: idle,
        builder: (context, _) {
          final level = controller.coreLevel();
          final breathe = 1 + 0.018 * math.sin(idle.value * math.pi * 2);
          final solved = controller.phase == PuzzlePhase.solved;
          final glow = 0.18 + 0.7 * level;
          Widget sprite = Image.asset(
            Art.sprite('core', 0),
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          );
          if (level > 0.02) {
            sprite = ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.white.withValues(alpha: 0.4 * level),
                BlendMode.srcATop,
              ),
              child: sprite,
            );
          }
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Positioned(
                left: -80,
                right: -80,
                top: 20,
                bottom: -30,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        accent.withValues(alpha: glow.clamp(0.0, 1.0)),
                        accent.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              Transform.scale(
                scale: breathe + (solved ? 0.08 * level : 0.05 * level),
                alignment: Alignment.bottomCenter,
                child: sprite,
              ),
            ],
          );
        },
      ),
    );
  }
}
