import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/game_settings.dart';
import '../game/world_data.dart';

/// Colour matrix that scales saturation and brightness.
ColorFilter tintMatrix({required double saturation, required double brightness}) {
  const lr = 0.2126;
  const lg = 0.7152;
  const lb = 0.0722;
  final s = saturation;
  final b = brightness;
  return ColorFilter.matrix(<double>[
    (lr * (1 - s) + s) * b, lg * (1 - s) * b, lb * (1 - s) * b, 0, 0,
    lr * (1 - s) * b, (lg * (1 - s) + s) * b, lb * (1 - s) * b, 0, 0,
    lr * (1 - s) * b, lg * (1 - s) * b, (lb * (1 - s) + s) * b, 0, 0,
    0, 0, 0, 1, 0,
  ]);
}

/// Isometric holographic pad under a region, drawn in the region colours.
class _GroundPainter extends CustomPainter {
  const _GroundPainter(this.accent, this.accent2, this.life);

  final Color accent;
  final Color accent2;

  /// 0..1 share of the region that is restored; brightens the pad.
  final double life;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width * 0.5, size.height * 0.7);
    final rx = size.width * 0.47;
    final ry = size.height * 0.25;
    final rect = Rect.fromCenter(center: c, width: rx * 2, height: ry * 2);
    final k = 0.5 + 0.5 * life;

    canvas.drawOval(
      rect.inflate(size.width * 0.04),
      Paint()
        ..shader = RadialGradient(
          colors: [accent.withValues(alpha: 0.30 * k), accent2.withValues(alpha: 0.10 * k), Colors.transparent],
          stops: const [0.2, 0.7, 1],
        ).createShader(rect.inflate(size.width * 0.04)),
    );

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    for (var i = 1; i <= 4; i++) {
      final f = i / 4;
      ring.color = Color.lerp(accent, accent2, f)!.withValues(alpha: (0.5 - f * 0.28) * k);
      canvas.drawOval(
        Rect.fromCenter(center: c, width: rx * 2 * f, height: ry * 2 * f),
        ring,
      );
    }
    final spoke = Paint()
      ..strokeWidth = 0.8
      ..color = accent.withValues(alpha: 0.2 * k);
    for (var a = 0; a < 12; a++) {
      final t = a * math.pi / 6;
      canvas.drawLine(c, c + Offset(math.cos(t) * rx, math.sin(t) * ry), spoke);
    }
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accent.withValues(alpha: 0.75 * k)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  @override
  bool shouldRepaint(_GroundPainter old) =>
      old.accent != accent || old.accent2 != accent2 || old.life != life;
}

class _Item {
  const _Item({
    required this.spot,
    required this.sprite,
    this.ruined,
    required this.state,
    required this.key,
    this.decor = false,
  });

  final SlotSpot spot;
  final SpriteRef sprite;
  final SpriteRef? ruined;
  final _State state;
  final int key;
  final bool decor;
}

enum _State { dormant, restored, reveal }

/// A region as a small diorama: every cleared level shows its object lit up,
/// the rest wait in the dark. `reveal` plays the restoration of one object.
class RegionDiorama extends StatefulWidget {
  const RegionDiorama({
    super.key,
    required this.region,
    required this.restoredMask,
    this.decorMask = 0,
    this.reveal,
    this.focus,
    this.aspect = 1.0,
    this.life,
  });

  final RegionDef region;
  final int restoredMask;
  final int decorMask;

  /// Level index whose object is being restored right now.
  final int? reveal;

  /// Level index to mark with a pulsing ring.
  final int? focus;
  final double aspect;
  final double? life;

  @override
  State<RegionDiorama> createState() => _RegionDioramaState();
}

class _RegionDioramaState extends State<RegionDiorama> with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();
  var _revealed = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.reveal != null) {
      _timer = Timer(const Duration(milliseconds: 750), () {
        if (mounted) setState(() => _revealed = true);
      });
    }
  }

  @override
  void didUpdateWidget(RegionDiorama old) {
    super.didUpdateWidget(old);
    if (old.reveal != widget.reveal) {
      _revealed = false;
      _timer?.cancel();
      if (widget.reveal != null) {
        _timer = Timer(const Duration(milliseconds: 750), () {
          if (mounted) setState(() => _revealed = true);
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _clock.dispose();
    super.dispose();
  }

  int get _restoredCount {
    var n = 0;
    for (var i = 0; i < 8; i++) {
      if (widget.restoredMask & (1 << i) != 0) n++;
    }
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final region = widget.region;
    final life = widget.life ?? _restoredCount / 8;
    return AspectRatio(
      aspectRatio: widget.aspect,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;
          final items = <_Item>[];
          for (var i = 0; i < 8; i++) {
            final done = widget.restoredMask & (1 << i) != 0;
            final revealing = widget.reveal == i;
            items.add(
              _Item(
                spot: slotSpots[i],
                sprite: region.slots[i].restored,
                ruined: region.slots[i].ruined,
                state: revealing
                    ? (_revealed ? _State.reveal : _State.dormant)
                    : (done ? _State.restored : _State.dormant),
                key: i,
              ),
            );
          }
          for (var i = 0; i < 4; i++) {
            if (widget.decorMask & (1 << i) != 0) {
              items.add(
                _Item(
                  spot: decorSpots[i],
                  sprite: region.decor[i].sprite,
                  state: _State.restored,
                  key: 100 + i,
                  decor: true,
                ),
              );
            }
          }
          items.sort((a, b) => a.spot.base.compareTo(b.spot.base));

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _GroundPainter(region.accent, region.accent2, life)),
              ),
              if (widget.focus != null) _focusRing(w, h),
              for (final item in items) _build(item, w, h, region),
            ],
          );
        },
      ),
    );
  }

  Widget _focusRing(double w, double h) {
    final spot = slotSpots[widget.focus!.clamp(0, 7)];
    return AnimatedBuilder(
      animation: _clock,
      builder: (context, _) {
        final t = (_clock.value * 4) % 1;
        final rw = spot.boxW * w * (0.7 + 0.5 * t);
        return Positioned(
          left: spot.cx * w - rw / 2,
          top: spot.base * h - rw * 0.2,
          width: rw,
          height: rw * 0.4,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.region.accent.withValues(alpha: 0.9 * (1 - t)),
                width: 2,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _build(_Item item, double w, double h, RegionDef region) {
    final spot = item.spot;
    final boxW = spot.boxW * w;
    final boxH = spot.boxH * h;
    final phase = item.key * 0.9;

    Widget picture(SpriteRef ref, {ColorFilter? filter, double opacity = 1}) {
      Widget image = Image.asset(
        ref.path,
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
      );
      if (filter != null) image = ColorFiltered(colorFilter: filter, child: image);
      return Opacity(opacity: opacity, child: image);
    }

    final restoredPicture = picture(item.sprite);
    final dormantPicture = item.ruined != null
        ? picture(item.ruined!, filter: tintMatrix(saturation: 0.75, brightness: 0.8))
        : picture(
            item.sprite,
            filter: tintMatrix(saturation: 0.12, brightness: 0.42),
            opacity: 0.62,
          );

    final lit = item.state != _State.dormant;
    Widget child = AnimatedSwitcher(
      duration: const Duration(milliseconds: 900),
      switchInCurve: Curves.easeOut,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.bottomCenter,
        children: [...previous, ?current],
      ),
      child: KeyedSubtree(
        key: ValueKey(lit),
        child: lit ? restoredPicture : dormantPicture,
      ),
    );

    if (lit || item.decor) {
      final bob = item.decor ? 3.5 : 1.8;
      child = AnimatedBuilder(
        animation: _clock,
        builder: (context, inner) => Transform.translate(
          offset: Offset(0, math.sin(_clock.value * math.pi * 2 + phase) * bob),
          child: inner,
        ),
        child: child,
      );
    }

    final soft = GameSettings.instance.softGlow;
    return Positioned(
      left: spot.cx * w - boxW / 2,
      top: spot.base * h - boxH,
      width: boxW,
      height: boxH,
      child: IgnorePointer(
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            if (lit && soft)
              Positioned(
                left: -boxW * 0.1,
                right: -boxW * 0.1,
                bottom: -boxH * 0.05,
                height: boxH * 0.26,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        region.accent.withValues(alpha: item.decor ? 0.28 : 0.42),
                        region.accent.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned.fill(child: child),
            if (item.state == _State.reveal) _RevealBurst(color: region.accent2, width: boxW),
          ],
        ),
      ),
    );
  }
}

/// Expanding rings and a light flash when an object comes back to life.
class _RevealBurst extends StatelessWidget {
  const _RevealBurst({required this.color, required this.width});

  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1500),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) {
          return CustomPaint(painter: _BurstPainter(t, color));
        },
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  const _BurstPainter(this.t, this.color);

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Offset(size.width / 2, size.height * 0.96);
    for (var i = 0; i < 3; i++) {
      final k = ((t * 1.25) - i * 0.18).clamp(0.0, 1.0);
      if (k <= 0 || k >= 1) continue;
      final r = size.width * (0.2 + 1.1 * k);
      canvas.drawOval(
        Rect.fromCenter(center: base, width: r * 2, height: r * 0.7),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - k)
          ..color = Color.lerp(color, Colors.white, 0.5)!.withValues(alpha: 0.9 * (1 - k)),
      );
    }
    final flash = (1 - t).clamp(0.0, 1.0);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, 0.4),
          radius: 0.9,
          colors: [Colors.white.withValues(alpha: 0.5 * flash), Colors.transparent],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}
