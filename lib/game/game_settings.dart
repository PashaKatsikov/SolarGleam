import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum GraphicsQuality { low, medium, high }

class GameSettings extends ChangeNotifier {
  GameSettings._();

  static final instance = GameSettings._();

  static const _vibrationKey = 'gleam_vibration';
  static const _musicKey = 'gleam_music';
  static const _sfxKey = 'gleam_sfx';
  static const _musicVolumeKey = 'gleam_music_volume';
  static const _sfxVolumeKey = 'gleam_sfx_volume';
  static const _qualityKey = 'gleam_quality';

  bool vibration = true;
  bool music = true;
  bool sfx = true;
  double musicVolume = 0.7;
  double sfxVolume = 0.9;
  GraphicsQuality quality = GraphicsQuality.high;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      vibration = prefs.getBool(_vibrationKey) ?? true;
      music = prefs.getBool(_musicKey) ?? true;
      sfx = prefs.getBool(_sfxKey) ?? true;
      musicVolume = prefs.getDouble(_musicVolumeKey) ?? 0.7;
      sfxVolume = prefs.getDouble(_sfxVolumeKey) ?? 0.9;
      final q = prefs.getInt(_qualityKey) ?? GraphicsQuality.high.index;
      quality = GraphicsQuality.values[q.clamp(0, 2)];
      notifyListeners();
    } catch (_) {
      // Keep the defaults when storage is unavailable.
    }
  }

  Future<void> _save(Future<void> Function(SharedPreferences prefs) write) async {
    notifyListeners();
    try {
      await write(await SharedPreferences.getInstance());
    } catch (_) {}
  }

  Future<void> setVibration(bool v) {
    vibration = v;
    return _save((p) => p.setBool(_vibrationKey, v));
  }

  Future<void> setMusic(bool v) {
    music = v;
    return _save((p) => p.setBool(_musicKey, v));
  }

  Future<void> setSfx(bool v) {
    sfx = v;
    return _save((p) => p.setBool(_sfxKey, v));
  }

  Future<void> setMusicVolume(double v) {
    musicVolume = v;
    return _save((p) => p.setDouble(_musicVolumeKey, v));
  }

  Future<void> setSfxVolume(double v) {
    sfxVolume = v;
    return _save((p) => p.setDouble(_sfxVolumeKey, v));
  }

  Future<void> setQuality(GraphicsQuality q) {
    quality = q;
    return _save((p) => p.setInt(_qualityKey, q.index));
  }

  /// How many ambient particles a screen may draw.
  int get particleBudget => switch (quality) {
    GraphicsQuality.low => 0,
    GraphicsQuality.medium => 14,
    GraphicsQuality.high => 28,
  };

  bool get softGlow => quality != GraphicsQuality.low;

  void tick() {
    if (vibration) HapticFeedback.selectionClick();
  }

  void light() {
    if (vibration) HapticFeedback.lightImpact();
  }

  void medium() {
    if (vibration) HapticFeedback.mediumImpact();
  }

  void heavy() {
    if (vibration) HapticFeedback.heavyImpact();
  }
}
