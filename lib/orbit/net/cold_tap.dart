import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Reads the cold-start destination written by the native SceneDelegate when
/// the app is launched by tapping a push notification. One-shot: the value is
/// cleared the moment it is read.
class ColdTap {
  /// MUST stay in sync with `SceneDelegate.launchRouteKey` on the Swift side
  /// (which carries the `flutter.` prefix: `flutter.sg_orbit_route`).
  static const String _key = 'sg_orbit_route';

  static Future<String?> consume() async {
    if (!Platform.isIOS) return null;
    try {
      final preferences = await SharedPreferences.getInstance();
      final value = preferences.getString(_key)?.trim();
      if (value == null || value.isEmpty) return null;
      await preferences.remove(_key);
      return value;
    } catch (_) {
      return null;
    }
  }
}
