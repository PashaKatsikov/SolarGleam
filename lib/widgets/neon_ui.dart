import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/sound.dart';
import '../game/game_settings.dart';
import '../game/world_data.dart';
import '../theme/neon_theme.dart';

/// Panel outline with two cut corners (top-left and bottom-right).
Path chamferPath(Size size, double cut, {double round = 3}) {
  final w = size.width;
  final h = size.height;
  final c = math.min(cut, math.min(w, h) / 2.2);
  final r = round;
  return Path()
    ..moveTo(c, 0)
    ..lineTo(w - r, 0)
    ..quadraticBezierTo(w, 0, w, r)
    ..lineTo(w, h - c)
    ..lineTo(w - c, h)
    ..lineTo(r, h)
    ..quadraticBezierTo(0, h, 0, h - r)
    ..lineTo(0, c)
    ..close();
}

class _PanelPainter extends CustomPainter {
  const _PanelPainter({
    required this.accent,
    required this.accent2,
    required this.cut,
    required this.fillAlpha,
    required this.glow,
    required this.soft,
    required this.strong,
  });

  final Color accent;
  final Color accent2;
  final double cut;
  final double fillAlpha;
  final double glow;
  final bool soft;
  final bool strong;

  @override
  void paint(Canvas canvas, Size size) {
    final path = chamferPath(size, cut);
    final rect = Offset.zero & size;

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Neon.panelHigh.withValues(alpha: fillAlpha),
            Neon.panel.withValues(alpha: fillAlpha),
          ],
        ).createShader(rect),
    );

    // faint scan lines give the glass a holographic grain
    canvas.save();
    canvas.clipPath(path);
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..strokeWidth = 1;
    for (var y = 3.0; y < size.height; y += 5) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, math.min(size.height * 0.5, 40)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [accent.withValues(alpha: 0.12), accent.withValues(alpha: 0)],
        ).createShader(rect),
    );
    canvas.restore();

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strong ? 1.8 : 1.2
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          accent.withValues(alpha: 0.95),
          accent2.withValues(alpha: 0.35),
          accent2.withValues(alpha: 0.9),
        ],
        stops: const [0, 0.55, 1],
      ).createShader(rect);

    if (soft && glow > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = accent.withValues(alpha: 0.28 * glow)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
    }
    canvas.drawPath(path, border);

    // bright ticks on the two cut corners
    final tick = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final c = math.min(cut, math.min(size.width, size.height) / 2.2);
    canvas.drawLine(Offset(c * 0.35, c * 0.65), Offset(c * 0.65, c * 0.35), tick);
    canvas.drawLine(
      Offset(size.width - c * 0.35, size.height - c * 0.65),
      Offset(size.width - c * 0.65, size.height - c * 0.35),
      tick,
    );
  }

  @override
  bool shouldRepaint(_PanelPainter old) =>
      old.accent != accent ||
      old.accent2 != accent2 ||
      old.cut != cut ||
      old.fillAlpha != fillAlpha ||
      old.glow != glow ||
      old.soft != soft ||
      old.strong != strong;
}

/// Glass panel with a gradient neon rim and cut corners.
class HoloPanel extends StatelessWidget {
  const HoloPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.accent = Neon.cyan,
    this.accent2 = Neon.violet,
    this.cut = 14,
    this.fillAlpha = 0.82,
    this.glow = 1,
    this.strong = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color accent;
  final Color accent2;
  final double cut;
  final double fillAlpha;
  final double glow;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: GameSettings.instance,
      builder: (context, _) => CustomPaint(
        painter: _PanelPainter(
          accent: accent,
          accent2: accent2,
          cut: cut,
          fillAlpha: fillAlpha,
          glow: glow,
          soft: GameSettings.instance.softGlow,
          strong: strong,
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class _ChamferClipper extends CustomClipper<Path> {
  const _ChamferClipper(this.cut);

  final double cut;

  @override
  Path getClip(Size size) => chamferPath(size, cut);

  @override
  bool shouldReclip(_ChamferClipper old) => old.cut != cut;
}

/// Pressable base that scales down while held.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.sound = Sfx.click,
    this.scale = 0.96,
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Sfx? sound;
  final double scale;
  final bool haptic;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  var _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      onTap: enabled
          ? () {
              if (widget.sound != null) Sound.instance.play(widget.sound!);
              if (widget.haptic) GameSettings.instance.tick();
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : 0.45,
          duration: const Duration(milliseconds: 150),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Main call-to-action button.
class NeonButton extends StatelessWidget {
  const NeonButton({
    super.key,
    required this.label,
    required this.onTap,
    this.accent = Neon.cyan,
    this.accent2 = Neon.violet,
    this.filled = true,
    this.icon,
    this.height = 54,
    this.sound = Sfx.click,
    this.fontSize = 17,
  });

  final String label;
  final VoidCallback? onTap;
  final Color accent;
  final Color accent2;
  final bool filled;
  final IconData? icon;
  final double height;
  final Sfx? sound;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final textColor = filled ? const Color(0xFF04112A) : Neon.text;
    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: fontSize + 4, color: textColor),
          const SizedBox(width: 9),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: oxa(fontSize, color: textColor, weight: 800, letterSpacing: 2.2),
          ),
        ),
      ],
    );
    return Pressable(
      onTap: onTap,
      sound: sound,
      child: SizedBox(
        height: height,
        child: filled
            ? ClipPath(
                clipper: const _ChamferClipper(14),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [accent, Color.lerp(accent, accent2, 0.65)!],
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Align(
                        alignment: Alignment.topCenter,
                        child: FractionallySizedBox(
                          heightFactor: 0.5,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(alpha: 0.38),
                                  Colors.white.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Center(child: content),
                    ],
                  ),
                ),
              )
            : HoloPanel(
                padding: EdgeInsets.zero,
                accent: accent,
                accent2: accent2,
                fillAlpha: 0.7,
                child: Center(child: content),
              ),
      ),
    );
  }
}

/// Square icon button used in the top bars.
class IconPad extends StatelessWidget {
  const IconPad({
    super.key,
    required this.icon,
    required this.onTap,
    this.accent = Neon.cyan,
    this.size = 46,
    this.sound = Sfx.click,
    this.badge,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color accent;
  final double size;
  final Sfx? sound;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      sound: sound,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: HoloPanel(
                padding: EdgeInsets.zero,
                cut: 11,
                accent: accent,
                fillAlpha: 0.75,
                child: Center(child: Icon(icon, size: size * 0.5, color: Neon.text)),
              ),
            ),
            if (badge != null)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge!,
                    style: oxa(11, color: const Color(0xFF04112A), weight: 800),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Energy counter with a rolling number.
class EnergyChip extends StatelessWidget {
  const EnergyChip({super.key, required this.value, this.compact = false});

  final int value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return HoloPanel(
      accent: Neon.gold,
      accent2: Neon.pink,
      cut: 10,
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 13, vertical: compact ? 6 : 8),
      fillAlpha: 0.78,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShaderMask(
            shaderCallback: (r) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFF2B0), Neon.gold],
            ).createShader(r),
            child: Icon(Icons.bolt_rounded, size: compact ? 18 : 22, color: Colors.white),
          ),
          const SizedBox(width: 4),
          TweenAnimationBuilder<double>(
            tween: Tween(end: value.toDouble()),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Text(
              formatCount(v.round()),
              style: oxa(compact ? 15 : 18, weight: 800, letterSpacing: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.count, this.size = 16, this.total = 3, this.spacing = 1});

  final int count;
  final double size;
  final int total;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing),
            child: Icon(
              Icons.star_rounded,
              size: size,
              color: i < count ? Neon.gold : Neon.faint.withValues(alpha: 0.55),
              shadows: i < count
                  ? [Shadow(color: Neon.gold.withValues(alpha: 0.8), blurRadius: size * 0.7)]
                  : null,
            ),
          ),
      ],
    );
  }
}

Color ruleColor(int bit) => switch (bit) {
  Rule.echo => Neon.cyan,
  Rule.mirror => Neon.violet,
  Rule.glyph => Neon.mint,
  Rule.ghost => Neon.pink,
  Rule.shift => Neon.gold,
  _ => Neon.dim,
};

IconData ruleIcon(int bit) => switch (bit) {
  Rule.echo => Icons.graphic_eq_rounded,
  Rule.mirror => Icons.flip_rounded,
  Rule.glyph => Icons.grid_view_rounded,
  Rule.ghost => Icons.blur_on_rounded,
  Rule.shift => Icons.swap_calls_rounded,
  _ => Icons.circle,
};

class RuleChip extends StatelessWidget {
  const RuleChip({super.key, required this.rule, this.small = false});

  final RuleInfo rule;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final color = ruleColor(rule.bit);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 7 : 10, vertical: small ? 3 : 5),
      decoration: ShapeDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BeveledRectangleBorder(
          borderRadius: BorderRadius.circular(7),
          side: BorderSide(color: color.withValues(alpha: 0.85), width: 1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ruleIcon(rule.bit), size: small ? 11 : 14, color: color),
          const SizedBox(width: 4),
          Text(
            rule.name,
            style: oxa(small ? 10 : 12, color: color, weight: 800, letterSpacing: 1.4),
          ),
        ],
      ),
    );
  }
}

/// Screen header: optional back pad, centred title block, trailing widget.
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
    this.accent = Neon.cyan,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            SizedBox(
              width: 70,
              child: Align(
                alignment: Alignment.centerLeft,
                child: onBack == null
                    ? null
                    : IconPad(
                        icon: Icons.arrow_back_ios_new_rounded,
                        accent: accent,
                        onTap: onBack,
                        sound: Sfx.close,
                      ),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      title,
                      maxLines: 1,
                      style: oxa(
                        19,
                        weight: 800,
                        letterSpacing: 2.6,
                        shadows: glowText(accent, blur: 10),
                      ),
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: oxa(11.5, color: Neon.dim, weight: 600, letterSpacing: 1.6),
                    ),
                ],
              ),
            ),
            SizedBox(
              width: 70,
              child: Align(alignment: Alignment.centerRight, child: trailing),
            ),
          ],
        ),
      ),
    );
  }
}

/// A thin progress rail with a glowing head.
class RailBar extends StatelessWidget {
  const RailBar({super.key, required this.value, this.color = Neon.cyan, this.height = 7});

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth * value.clamp(0.0, 1.0);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(height),
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                width: w,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(height),
                  gradient: LinearGradient(colors: [color.withValues(alpha: 0.55), color]),
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8)],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
