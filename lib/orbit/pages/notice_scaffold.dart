import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/gleam_theme.dart';

/// Painted (asset-free) backdrop for the full-screen notice pages: a night
/// gradient with a soft glow and faint rings behind the content.
class NoticeBackdrop extends StatelessWidget {
  const NoticeBackdrop({super.key, required this.child, this.glow});

  final Widget child;

  /// Tint of the top glow (defaults to the gold used across the app).
  final Color? glow;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF120B2A), Color(0xFF09061A), Color(0xFF050309)],
          stops: <double>[0.0, 0.52, 1.0],
        ),
      ),
      child: CustomPaint(
        painter: _OrbitPainter(glow ?? GleamColors.gold),
        isComplex: true,
        willChange: false,
        child: child,
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter(this.glow);

  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.34);

    final glowRadius = size.shortestSide * 0.72;
    canvas.drawCircle(
      center,
      glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[glow.withValues(alpha: 0.22), Colors.transparent],
        ).createShader(Rect.fromCircle(center: center, radius: glowRadius)),
    );

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = glow.withValues(alpha: 0.10);
    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(center, size.shortestSide * (0.26 + i * 0.16), ring);
    }

    final star = Paint()..color = Colors.white.withValues(alpha: 0.35);
    final rng = math.Random(7);
    for (var i = 0; i < 48; i++) {
      final dx = rng.nextDouble() * size.width;
      final dy = rng.nextDouble() * size.height;
      canvas.drawCircle(Offset(dx, dy), rng.nextDouble() * 1.1 + 0.3, star);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) =>
      oldDelegate.glow != glow;
}

/// Glowing circular badge holding a single themed icon.
class NoticeBadge extends StatelessWidget {
  const NoticeBadge({super.key, required this.icon, this.size = 108});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: <Color>[Color(0xFF241A3C), Color(0xFF130C24)],
        ),
        border: Border.all(color: GleamColors.gold.withValues(alpha: 0.55), width: 2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: GleamColors.goldDeep.withValues(alpha: 0.45),
            blurRadius: 34,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(icon, size: size * 0.46, color: GleamColors.gold),
    );
  }
}

/// Centered, scrollable page: backdrop, badge, title, subtitle and a stack of
/// action buttons. Scrolls so the buttons never overlap the copy in any
/// orientation.
class NoticePanel extends StatelessWidget {
  const NoticePanel({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actions,
    this.footer,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> actions;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    final badge = landscape ? 84.0 : 112.0;

    return NoticeBackdrop(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  NoticeBadge(icon: icon, size: badge),
                  SizedBox(height: landscape ? 20 : 30),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: cinzel(
                      landscape ? 23 : 27,
                      GleamColors.goldLight,
                      weight: 700,
                      height: 1.18,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: rajdhani(
                      landscape ? 17 : 19,
                      Colors.white.withValues(alpha: 0.78),
                      weight: FontWeight.w600,
                    ).copyWith(height: 1.3),
                  ),
                  SizedBox(height: landscape ? 28 : 44),
                  ...actions,
                  if (footer != null) ...<Widget>[
                    const SizedBox(height: 16),
                    footer!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded gold action button used on the notice pages.
class NoticeButton extends StatelessWidget {
  const NoticeButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.emphasized = true,
    this.busy = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool emphasized;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    const radius = 34.0;
    final gradient = emphasized
        ? const <Color>[Color(0xFFFFE7A3), Color(0xFFC8882B)]
        : const <Color>[Color(0xFF3A2E52), Color(0xFF241A3C)];
    final foreground =
        emphasized ? const Color(0xFF2A1A06) : GleamColors.goldLight;

    return SizedBox(
      width: double.infinity,
      height: 62,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(
            color: emphasized
                ? const Color(0xFF5A3A12)
                : GleamColors.gold.withValues(alpha: 0.45),
            width: emphasized ? 2.5 : 1.6,
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 5)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: busy ? null : onTap,
            child: Center(
              child: busy
                  ? SizedBox.square(
                      dimension: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        color: foreground,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (icon != null) ...<Widget>[
                          Icon(icon, color: foreground, size: 24),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          label,
                          style: TextStyle(
                            color: foreground,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
