import 'package:flutter/material.dart';

class GleamColors {
  static const night = Color(0xFF07040C);
  static const plaque = Color(0xE6080C1E);
  static const gold = Color(0xFFF0C14B);
  static const goldDeep = Color(0xFFC8882B);
  static const goldLight = Color(0xFFFFF1C9);
  static const ivory = Color(0xFFFFF6E4);
  static const ink = Color(0xFF1A1208);
}

TextStyle cinzel(
  double size,
  Color color, {
  double weight = 700,
  double? height,
  double letterSpacing = 0.6,
}) {
  return TextStyle(
    fontFamily: 'Cinzel',
    fontSize: size,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
    fontVariations: [FontVariation.weight(weight)],
  );
}

TextStyle rajdhani(
  double size,
  Color color, {
  FontWeight weight = FontWeight.w700,
}) {
  return TextStyle(
    fontFamily: 'Rajdhani',
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: 1,
  );
}

String formatGleam(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return negative ? '-$buffer' : buffer.toString();
}

ThemeData buildGleamTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: GleamColors.night,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    fontFamily: 'Rajdhani',
  );
}
