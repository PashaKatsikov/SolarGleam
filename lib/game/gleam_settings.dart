import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GleamSettings extends ChangeNotifier {
  GleamSettings._();

  static final instance = GleamSettings._();
  static const _vibrationKey = 'gleam_vibration';

  bool vibration = true;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      vibration = prefs.getBool(_vibrationKey) ?? true;
      notifyListeners();
    } catch (_) {
      // Keep vibration on when storage is unavailable.
    }
  }

  Future<void> setVibration(bool value) async {
    vibration = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_vibrationKey, value);
    } catch (_) {}
  }

  void selection() {
    if (vibration) HapticFeedback.selectionClick();
  }

  void medium() {
    if (vibration) HapticFeedback.mediumImpact();
  }

  void heavy() {
    if (vibration) HapticFeedback.heavyImpact();
  }
}
