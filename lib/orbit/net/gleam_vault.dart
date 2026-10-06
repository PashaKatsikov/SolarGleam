import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/flow_models.dart';

/// Session persistence.
class GleamVault {
  static const String _routeKey = 'app.flow.mode';
  static const String _expiryKey = 'app.flow.ttl';
  static const String _inviteKey = 'app.prompt.next';
  static const String _permissionKey = 'app.push.enabled';
  static const String _osDeniedKey = 'app.push.blocked';
  static const String _savedUrlKey = 'app.flow.cache';

  /// Fallback lifetime for a saved URL when the response omits `expires` — a
  /// stale URL must not live forever.
  static const int savedUrlExpiryDays = 7;

  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  late SharedPreferences _preferences;

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
  }

  GleamRoute get route => GleamRoute.parse(_preferences.getString(_routeKey));

  Future<void> saveRoute(GleamRoute route) =>
      _preferences.setString(_routeKey, route.storageValue);

  Future<String?> savedUrl() async {
    try {
      return await _secure.read(key: _savedUrlKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheUrl(String url, int? expiresAt) async {
    try {
      await _secure.write(key: _savedUrlKey, value: url);
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final fallback = nowSec + savedUrlExpiryDays * 86400;
      await _preferences.setInt(_expiryKey, expiresAt ?? fallback);
    } catch (_) {}
  }

  bool get cachedUrlExpired {
    final expiry = _preferences.getInt(_expiryKey);
    return expiry == null ||
        DateTime.now().millisecondsSinceEpoch ~/ 1000 >= expiry;
  }

  bool get pushAllowed => _preferences.getBool(_permissionKey) ?? false;
  bool get pushDeniedByOs => _preferences.getBool(_osDeniedKey) ?? false;

  Future<void> setPushAllowed(bool value) =>
      _preferences.setBool(_permissionKey, value);

  Future<void> markPushDeniedByOs() =>
      _preferences.setBool(_osDeniedKey, true);

  bool get shouldShowPushInvite {
    if (pushAllowed || pushDeniedByOs) return false;
    final after = _preferences.getInt(_inviteKey);
    return after == null ||
        DateTime.now().millisecondsSinceEpoch ~/ 1000 >= after;
  }

  Future<void> snoozePushInvite(int epochSeconds) =>
      _preferences.setInt(_inviteKey, epochSeconds);
}
