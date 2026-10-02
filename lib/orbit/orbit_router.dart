import 'dart:async';
import 'dart:io';

import 'config/orbit_config.dart';
import 'core/relay_models.dart';
import 'net/cold_tap.dart';
import 'net/config_call.dart';
import 'net/gleam_vault.dart';
import 'net/push_beacon.dart';
import 'net/reach_sensor.dart';
import 'net/solar_agent.dart';
import 'net/track_relay.dart';
import 'net/trace.dart';

/// Decides where boot should land: native game, portal WebView, or offline.
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
  final TrackRelay track;
  final ConfigCall call;
  final PushBeacon push;
  final SolarAgent agent;
  final bool runtimeEnabled;

  bool get enabled => runtimeEnabled && OrbitConfig.grayCredentialsReady;

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
      glmTrace(
        () => '[GLM.ROUTE] gate disabled runtime=$runtimeEnabled '
            'creds=${OrbitConfig.grayCredentialsReady}',
      );
      onProgress(1);
      return const NativeStop();
    }

    glmTrace(() => '[GLM.ROUTE] decide start route=${vault.route}');

    push.onTokenChanged = _refreshForToken;
    final coldRoute = await ColdTap.consume();
    if (coldRoute != null) {
      await vault.saveRoute(GleamRoute.portal);
      await vault.consumePushUrl();
      unawaited(_backgroundDispatch());
      onProgress(1);
      return PortalStop(coldRoute, coldLaunch: true);
    }

    onProgress(0.12);
    return switch (vault.route) {
      GleamRoute.undecided => _firstDecision(onProgress),
      GleamRoute.portal => _returningPortal(onProgress),
      GleamRoute.native => _returningNative(onProgress),
    };
  }

  Future<GleamStop> _firstDecision(void Function(double) progress) async {
    if (!await sensor.hasInterface()) {
      return const OfflineStop(returnToNative: false);
    }
    progress(0.28);
    try {
      await push.boot();
    } catch (_) {}
    if (!await sensor.canReachNetwork()) {
      return const OfflineStop(returnToNative: false);
    }
    progress(0.48);
    await track.awaitSignals();
    progress(0.72);
    final reply = await _requestConfig();
    progress(1);
    glmTrace(
      () => '[GLM.ROUTE] first config hasDest=${reply.hasDestination} '
          'url=${reply.url}',
    );
    if (reply.hasDestination) {
      await vault.saveRoute(GleamRoute.portal);
      return PortalStop(reply.url!);
    }
    await vault.saveRoute(GleamRoute.native);
    return const NativeStop();
  }

  Future<GleamStop> _returningPortal(void Function(double) progress) async {
    if (!await sensor.hasInterface()) {
      return const OfflineStop(returnToNative: false);
    }
    final pending = await vault.consumePushUrl();
    if (pending != null && pending.isNotEmpty) {
      progress(1);
      return PortalStop(pending);
    }
    final cached = await vault.savedUrl();
    if (cached != null && !vault.cachedUrlExpired) {
      progress(1);
      return PortalStop(cached);
    }

    await Future.wait<void>(<Future<void>>[push.boot(), track.start()]);
    if (!await sensor.canReachNetwork()) {
      return const OfflineStop(returnToNative: false);
    }
    progress(0.62);
    await track.awaitSignals(installTimeout: const Duration(seconds: 7));
    final reply = await _requestConfig();
    progress(1);
    if (reply.hasDestination) return PortalStop(reply.url!);
    if (cached != null) return PortalStop(cached);
    return const OfflineStop(returnToNative: false);
  }

  Future<GleamStop> _returningNative(void Function(double) progress) async {
    if (!await sensor.hasInterface()) {
      progress(1);
      return const NativeStop();
    }
    await Future.wait<void>(<Future<void>>[push.boot(), track.start()]);
    if (!await sensor.canReachNetwork()) {
      progress(1);
      return const NativeStop();
    }
    progress(0.55);
    await track.awaitSignals();
    final reply = await _requestConfig();
    progress(1);
    if (!reply.hasDestination) return const NativeStop();
    await vault.saveRoute(GleamRoute.portal);
    return PortalStop(reply.url!);
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
