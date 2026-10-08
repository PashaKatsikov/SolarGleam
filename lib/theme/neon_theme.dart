import 'package:flutter/material.dart';

/// Palette and type of the holographic UI.
class Neon {
  static const void0 = Color(0xFF03040C);
  static const space = Color(0xFF070A20);
  static const panel = Color(0xFF0C1230);
  static const panelHigh = Color(0xFF161E4C);
  static const edge = Color(0xFF3B4C9E);

  static const text = Color(0xFFEAF3FF);
  static const dim = Color(0xFF8D9BCB);
  static const faint = Color(0xFF55618F);

  static const cyan = Color(0xFF35D6FF);
  static const pink = Color(0xFFFF4FD8);
  static const violet = Color(0xFF8E6BFF);
  static const gold = Color(0xFFFFC857);
  static const mint = Color(0xFF4DFFC3);
  static const red = Color(0xFFFF5470);
}

TextStyle oxa(
  double size, {
  Color color = Neon.text,
  double weight = 600,
  double letterSpacing = 0,
  double? height,
  List<Shadow>? shadows,
}) {
  return TextStyle(
    fontFamily: 'Oxanium',
    fontSize: size,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
    shadows: shadows,
    fontVariations: [FontVariation.weight(weight)],
  );
}

List<Shadow> glowText(Color color, {double blur = 14}) => [
  Shadow(color: color.withValues(alpha: 0.85), blurRadius: blur),
  Shadow(color: color.withValues(alpha: 0.45), blurRadius: blur * 2),
];

String formatCount(int value) {
  final digits = value.abs().toString();
  final out = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

ThemeData buildNeonTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Neon.void0,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    fontFamily: 'Oxanium',
    colorScheme: const ColorScheme.dark(
      primary: Neon.cyan,
      secondary: Neon.pink,
      surface: Neon.panel,
    ),
  );
}
