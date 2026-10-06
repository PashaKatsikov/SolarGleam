import 'dart:async';
import 'dart:io';

import 'config/orbit_config.dart';
import 'core/flow_models.dart';
import 'net/config_call.dart';
import 'net/gleam_vault.dart';
import 'net/push_agent.dart';
import 'net/reach_sensor.dart';
import 'net/solar_agent.dart';
import 'net/signal_collector.dart';

/// Decides where boot lands: the native game, the web view, or the offline
/// screen.
class OrbitRouter {
  OrbitRouter({
    required this.vault,
    required this.sensor,
    required this.track,
    required this.call,
    required this.push,
    required this.agent,
    required this.runtimeEnabled,
  });

  final GleamVault vault;
  final ReachSensor sensor;
  final SignalCollector track;
  final ConfigCall call;
  final PushAgent push;
  final SolarAgent agent;
  final bool runtimeEnabled;

  bool get enabled => runtimeEnabled && OrbitConfig.credentialsReady;

  Future<GleamStop>? _decideFuture;

  /// De-duplicates only *concurrent* calls (the splash can build twice at
  /// startup). The cache is cleared once the pipeline finishes, so a later
  /// Retry re-runs the whole pipeline instead of replaying a cached stop.
  Future<GleamStop> decide({
    required void Function(double value) onProgress,
  }) =>
      _decideFuture ??= _decide(onProgress: onProgress)
          .whenComplete(() => _decideFuture = null);

  Future<GleamStop> _decide({
    required void Function(double value) onProgress,
  }) async {
    if (!enabled) {
      onProgress(1);
      return const NativeStop();
    }

    push.onTokenChanged = _refreshForToken;

    // Presence is decided by the active connection only (no DNS), so an offline
    // boot bails out before touching the network or filling the progress bar.
    final online = await sensor.hasInterface();
    final route = vault.route;

    if (!online) {
      // The native game never needs internet on a returning launch.
      if (route == GleamRoute.native) {
        onProgress(1);
        return const NativeStop();
      }
      // Other launches need internet: show the offline screen at once, without
      // a misleading full progress bar. Nothing is booted here, so a later
      // Retry re-runs the whole pipeline once the connection is back.
      return const OfflineStop(returnToNative: false);
    }

    // A cold-launch deep link opens straight into the web view. The target is
    // used in-flight and never persisted.
    final tapped = await push.coldTapDestination();
    if (tapped != null && tapped.isNotEmpty) {
      await vault.saveRoute(GleamRoute.portal);
      unawaited(push.boot());
      unawaited(_backgroundDispatch());
      onProgress(1);
      return WebStop(tapped, coldLaunch: true);
    }

    onProgress(0.12);
    return switch (route) {
      GleamRoute.undecided => _firstDecision(onProgress),
      GleamRoute.portal => _returningPortal(onProgress),
      GleamRoute.native => _returningNative(onProgress),
    };
  }

  // Everything below runs only when the device is online (see `_decide`).

  Future<GleamStop> _firstDecision(void Function(double) progress) async {
    progress(0.28);
    try {
      await push.boot();
    } catch (_) {}
    progress(0.48);
    await track.awaitSignals();
    progress(0.72);
    final reply = await _requestConfig();
    progress(1);
    if (reply.hasDestination) {
      await vault.saveRoute(GleamRoute.portal);
      return WebStop(reply.url!);
    }
    await vault.saveRoute(GleamRoute.native);
    return const NativeStop();
  }

  Future<GleamStop> _returningPortal(void Function(double) progress) async {
    final cached = await vault.savedUrl();
    if (cached != null && !vault.cachedUrlExpired) {
      progress(1);
      return WebStop(cached);
    }

    await Future.wait<void>(<Future<void>>[push.boot(), track.start()]);
    progress(0.62);
    await track.awaitSignals(installTimeout: const Duration(seconds: 7));
    final reply = await _requestConfig();
    progress(1);
    if (reply.hasDestination) return WebStop(reply.url!);
    if (cached != null) return WebStop(cached);
    return const OfflineStop(returnToNative: false);
  }

  Future<GleamStop> _returningNative(void Function(double) progress) async {
    await Future.wait<void>(<Future<void>>[push.boot(), track.start()]);
    progress(0.55);
    await track.awaitSignals();
    final reply = await _requestConfig();
    progress(1);
    if (!reply.hasDestination) return const NativeStop();
    await vault.saveRoute(GleamRoute.portal);
    return WebStop(reply.url!);
  }

  Future<ConfigReply> _requestConfig({String? token}) async {
    final body = await track.compose(
      locale: Platform.localeName.replaceAll('-', '_'),
      pushToken: token ?? push.token,
    );
    return call.request(body);
  }

  Future<void> _backgroundDispatch() async {
    try {
      await Future.wait<void>(<Future<void>>[
        push.boot(),
        track.awaitSignals(),
      ]);
      await _requestConfig();
    } catch (_) {}
  }

  Future<void> _refreshForToken(String token) async {
    try {
      await _requestConfig(token: token);
    } catch (_) {}
  }
}
