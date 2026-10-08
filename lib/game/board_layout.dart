import 'dart:math' as math;
import 'dart:ui';

/// Where orb slots sit on the isometric platform. Coordinates are in units of
/// the board width, measured from the board centre (y grows downwards).
class SlotPose {
  const SlotPose(this.x, this.y);

  final double x;
  final double y;
}

class BoardLayout {
  BoardLayout._();

  /// Orb diameter as a share of the board width.
  static double orbSize(int count) => switch (count) {
    <= 3 => 0.215,
    4 => 0.205,
    5 => 0.195,
    6 => 0.18,
    7 => 0.168,
    8 => 0.158,
    9 => 0.145,
    10 => 0.14,
    11 => 0.135,
    _ => 0.13,
  };

  static List<SlotPose> poses(int count) {
    if (count <= 8) {
      // Half a step off the vertical, so no orb hides behind the core.
      return _ring(count, 0.375, 0.225, -math.pi / 2 + math.pi / count);
    }
    final outer = (count * 0.58).round();
    final inner = count - outer;
    return [
      ..._ring(outer, 0.405, 0.245, -math.pi / 2 + math.pi / outer),
      ..._ring(inner, 0.205, 0.12, -math.pi / 2),
    ];
  }

  static List<SlotPose> _ring(int n, double rx, double ry, double start) {
    return [
      for (var k = 0; k < n; k++)
        SlotPose(
          rx * math.cos(start + 2 * math.pi * k / n),
          ry * math.sin(start + 2 * math.pi * k / n),
        ),
    ];
  }

  /// Orbs lower on the screen are nearer the camera and drawn a little larger.
  static double depthScale(double y) => (0.9 + 0.2 * ((y + 0.3) / 0.6)).clamp(0.86, 1.1);

  static Offset toOffset(SlotPose pose, double width) => Offset(pose.x * width, pose.y * width);
}
