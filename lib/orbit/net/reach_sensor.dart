import 'package:connectivity_plus/connectivity_plus.dart';

/// Connectivity checks.
///
/// Reachability is decided purely by the active network interface
/// (Wi-Fi / cellular / ethernet) via connectivity_plus — NOT by a DNS lookup
/// or HTTP probe. A DNS probe can hang for seconds and report a false
/// "offline" behind a VPN or a slow resolver; the connection check is instant
/// and reflects whether the device actually has a link.
class ReachSensor {
  final Connectivity _connectivity = Connectivity();

  /// True when the device currently has a network connection.
  Future<bool> hasInterface() async {
    try {
      final status = await _connectivity.checkConnectivity();
      return status.any((value) => value != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  /// Internet presence, based on the active connection (no DNS / HTTP probe).
  Future<bool> canReachNetwork() => hasInterface();

  Stream<List<ConnectivityResult>> get changes =>
      _connectivity.onConnectivityChanged;
}
