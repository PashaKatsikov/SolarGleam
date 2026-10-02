import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/relay_models.dart';

/// Session persistence for the gray flow.
class GleamVault {
  static const String _routeKey = 'sg.orbit.route';
  static const String _expiryKey = 'sg.orbit.expiry';
  static const String _inviteKey = 'sg.orbit.invite.after';
  static const String _permissionKey = 'sg.orbit.push.allowed';
  static const String _osDeniedKey = 'sg.orbit.push.os_denied';
  static const String _savedUrlKey = 'sg.orbit.secure.destination';
  static const String _pendingUrlKey = 'sg.orbit.secure.pending';

  /// Fallback lifetime for a saved portal URL when the relay omits
  /// `expires` — a stale URL from an old response must not live forever.
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

  Future<void> stashPushUrl(String url) async {
    if (url.trim().isEmpty) return;
    try {
      await _secure.write(key: _pendingUrlKey, value: url.trim());
    } catch (_) {}
  }

  Future<String?> consumePushUrl() async {
    try {
      final value = await _secure.read(key: _pendingUrlKey);
      if (value != null) await _secure.delete(key: _pendingUrlKey);
      return value;
    } catch (_) {
      return null;
    }
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
