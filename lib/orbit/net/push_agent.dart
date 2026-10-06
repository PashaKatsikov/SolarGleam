import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'gleam_vault.dart';

@pragma('vm:entry-point')
Future<void> backgroundMessageHandler(RemoteMessage _) async {}

/// FCM/APNs wrapper: token lifecycle, permission prompt, and extracting a
/// destination URL from a tapped notification.
///
/// A tap is the only thing that yields a destination here, and that URL is
/// never written to disk — it is held in memory just long enough to hand to the
/// web view, then dropped.
class PushAgent {
  PushAgent(this._vault, {required this.enabled});

  final GleamVault _vault;
  final bool enabled;
  FirebaseMessaging? _messaging;
  Future<void>? _bootFuture;
  Future<bool>? _permissionFuture;
  String? _token;

  /// Destination from a tap received before anyone was listening. One-shot.
  String? _pendingDestination;

  void Function(String url)? _onDestination;
  void Function(String token)? onTokenChanged;

  String? get token => _token;

  /// Set by the web view: a tap loads straight into it. When a listener
  /// attaches, any tap that arrived earlier is delivered immediately.
  set onDestination(void Function(String url)? value) {
    _onDestination = value;
    final pending = _pendingDestination;
    if (value != null && pending != null) {
      _pendingDestination = null;
      value(pending);
    }
  }

  void Function(String url)? get onDestination => _onDestination;

  /// Fast path for routing: the destination of the notification that
  /// cold-launched the app (terminated → tapped), or null. Does not wait for
  /// the full [boot]; the URL is returned, never stored.
  Future<String?> coldTapDestination() async {
    if (!enabled) return null;
    final messaging = _messaging ??= FirebaseMessaging.instance;
    try {
      final initial = await messaging.getInitialMessage().timeout(
        const Duration(seconds: 4),
        onTimeout: () => null,
      );
      return initial == null ? null : _extract(initial.data);
    } catch (_) {
      return null;
    }
  }

  Future<void> boot() => _bootFuture ??= _boot();

  Future<void> _boot() async {
    if (!enabled) return;
    final messaging = _messaging ??= FirebaseMessaging.instance;

    FirebaseMessaging.onBackgroundMessage(backgroundMessageHandler);
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    messaging.onTokenRefresh.listen((value) {
      _token = value;
      onTokenChanged?.call(value);
    });
    // A tap while the app is backgrounded brings the destination here.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final url = _extract(message.data);
      if (url == null) return;
      _deliverTap(url);
    });
    await _waitForApns();
    _token = await messaging.getToken();
  }

  void _deliverTap(String url) {
    final callback = _onDestination;
    if (callback != null) {
      callback(url);
    } else {
      // No listener yet (e.g. still on the notify gate) — hold it in memory.
      _pendingDestination = url;
    }
  }

  String? _extract(Map<String, dynamic> payload) => destinationFrom(payload);

  /// Pulls the destination URL out of an FCM payload and normalizes its scheme.
  ///
  /// Pure and static so it can be unit-tested without Firebase. `http` links
  /// are kept exactly as `http` (they load fine in the WKWebView thanks to
  /// `NSAllowsArbitraryLoadsInWebContent`), `https` is kept as-is, and a
  /// scheme-less value (e.g. `promo.example.com/x`) defaults to `https` so the
  /// web view never receives an unloadable scheme-less URL.
  static String? destinationFrom(Map<String, dynamic> payload) {
    for (final key in const <String>[
      'deep_link',
      'target',
      'url',
      'deeplink',
      'link',
    ]) {
      final value = payload[key];
      if (value is String) {
        final normalized = normalizeUrl(value);
        if (normalized != null) return normalized;
      }
    }
    for (final container in const <String>['payload', 'data']) {
      final nested = payload[container];
      if (nested is Map) {
        final found = destinationFrom(Map<String, dynamic>.from(nested));
        if (found != null) return found;
      }
    }
    return null;
  }

  /// Normalizes a raw push link. Returns null when it is not usable.
  static String? normalizeUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    // A proper http(s) link — keep the scheme verbatim so http stays http.
    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty) {
      return trimmed;
    }
    // Scheme-less host/path — default to https so the web view can load it.
    if (!trimmed.contains('://')) {
      final guess = Uri.tryParse('https://$trimmed');
      if (guess != null && guess.host.isNotEmpty) return guess.toString();
    }
    // Any other real scheme (app deep links) — pass through untouched.
    if (uri != null && uri.hasScheme) return trimmed;
    return null;
  }

  // APNs poll cadence rotated per project (7 x 620ms base; longer after
  // the user grants permission).
  Future<void> _waitForApns({int attempts = 7}) async {
    final messaging = _messaging;
    if (messaging == null) return;
    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        if ((await messaging.getAPNSToken())?.isNotEmpty ?? false) return;
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 620));
    }
  }

  Future<bool> canOfferPermission() async {
    if (!enabled || _vault.pushDeniedByOs) return false;
    final messaging = _messaging;
    if (messaging == null) return false;
    final status =
        (await messaging.getNotificationSettings()).authorizationStatus;
    if (status == AuthorizationStatus.denied) {
      await _vault.markPushDeniedByOs();
      return false;
    }
    return status == AuthorizationStatus.notDetermined ||
        status == AuthorizationStatus.provisional;
  }

  Future<bool> askPermission() {
    return _permissionFuture ??= _performPermissionRequest().whenComplete(
      () => _permissionFuture = null,
    );
  }

  Future<bool> _performPermissionRequest() async {
    if (!enabled || _messaging == null) return false;
    final result = await _messaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    final accepted =
        result.authorizationStatus == AuthorizationStatus.authorized ||
        result.authorizationStatus == AuthorizationStatus.provisional;
    await _vault.setPushAllowed(accepted);
    if (!accepted &&
        result.authorizationStatus == AuthorizationStatus.denied) {
      await _vault.markPushDeniedByOs();
    }
    if (accepted) {
      await _waitForApns(attempts: 16);
      _token = await _messaging!.getToken();
      if (_token?.isNotEmpty ?? false) onTokenChanged?.call(_token!);
    }
    return accepted;
  }
}
