import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GleamSettings extends ChangeNotifier {
  GleamSettings._();

  static final instance = GleamSettings._();
  static const _vibrationKey = 'gleam_vibration';
  static const _photoKey = 'gleam_profile_photo';

  bool vibration = true;

  /// Absolute path to the saved profile photo, or null when none is set.
  String? profilePhotoPath;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      vibration = prefs.getBool(_vibrationKey) ?? true;
      final path = prefs.getString(_photoKey);
      profilePhotoPath =
          (path != null && File(path).existsSync()) ? path : null;
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

  /// Copies the picked image into app storage under a fresh name (so the image
  /// cache never serves a stale avatar) and persists its path.
  Future<void> setProfilePhoto(String sourcePath) async {
    final dir = await getApplicationDocumentsDirectory();
    final dest =
        '${dir.path}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(sourcePath).copy(dest);
    final previous = profilePhotoPath;
    profilePhotoPath = dest;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_photoKey, dest);
    } catch (_) {}
    if (previous != null && previous != dest) {
      try {
        await File(previous).delete();
      } catch (_) {}
    }
  }

  Future<void> clearProfilePhoto() async {
    final previous = profilePhotoPath;
    profilePhotoPath = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_photoKey);
    } catch (_) {}
    if (previous != null) {
      try {
        await File(previous).delete();
      } catch (_) {}
    }
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
