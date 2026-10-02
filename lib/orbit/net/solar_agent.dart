import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import '../config/orbit_config.dart';

/// HTTP client that stamps a real mobile browser User-Agent on every request.
///
/// GAME THEME CATEGORY: slot (app-identity suffix intentionally OMITTED —
/// the operator confirmed none is required). Every UA fragment, including the
/// browser scaffolding, is assembled at runtime from encoded byte arrays in
/// [OrbitConfig]; no plaintext browser literal ships in the binary.
class SolarAgent extends http.BaseClient {
  final http.Client _transport = http.Client();
  String? _userAgent;

  Future<void> prepare() async {
    try {
      if (!Platform.isIOS) {
        _userAgent = _mobileSafari('18.5');
        return;
      }
      final info = await DeviceInfoPlugin().iosInfo;
      _userAgent = _mobileSafari(_normalizedIos(info.systemVersion));
    } catch (_) {
      _userAgent = _mobileSafari('18.5');
    }
  }

  String get userAgent => _userAgent ??= _mobileSafari('18.5');

  String _normalizedIos(String raw) {
    final parts = raw
        .split('.')
        .map(int.tryParse)
        .whereType<int>()
        .take(3)
        .toList();
    if (parts.isEmpty || parts.first < 18) return '18.5';
    return parts.join('.');
  }

  String _mobileSafari(String iosVersion) {
    final cpu = iosVersion.replaceAll('.', '_');
    return '${OrbitConfig.uaProduct} '
        '${OrbitConfig.uaPlatformPrefix} $cpu '
        '${OrbitConfig.uaPlatformSuffix} '
        '${OrbitConfig.uaEngine} '
        'Version/${OrbitConfig.safariVersion} '
        '${OrbitConfig.uaMobileToken} '
        'Safari/${OrbitConfig.safariTail}';
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.putIfAbsent('User-Agent', () => userAgent);
    return _transport.send(request);
  }

  @override
  void close() => _transport.close();
}
