import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'orbit/config/orbit_config.dart';
import 'orbit/net/config_call.dart';
import 'orbit/net/gleam_vault.dart';
import 'orbit/net/push_beacon.dart';
import 'orbit/net/reach_sensor.dart';
import 'orbit/net/solar_agent.dart';
import 'orbit/net/track_relay.dart';
import 'orbit/net/trace.dart';
import 'orbit/orbit_router.dart';
import 'screens/splash_screen.dart';
import 'theme/gleam_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final vault = GleamVault();
  final agent = SolarAgent();
  await Future.wait<void>(<Future<void>>[
    vault.initialize(),
    agent.prepare(),
  ]);

  glmTrace(
    () => '[GLM.BOOT] credsReady=${OrbitConfig.grayCredentialsReady} '
        'endpoint=${OrbitConfig.endpoint} '
        'afKeyLen=${OrbitConfig.appsFlyerKey.length} '
        'fbNum=${OrbitConfig.firebaseProjectNumber}',
  );

  var productionServicesReady = false;
  if (OrbitConfig.grayCredentialsReady) {
    try {
      await Firebase.initializeApp();
      productionServicesReady = true;
    } catch (error) {
      glmTrace(() => '[GLM.BOOT] Firebase init failed: $error');
    }
    if (productionServicesReady) {
      try {
        await FirebaseAppCheck.instance.activate(
          providerApple: kDebugMode
              ? const AppleDebugProvider()
              : const AppleAppAttestWithDeviceCheckFallbackProvider(),
        );
      } catch (error) {
        // App Check must never block FCM / gray routing.
        glmTrace(() => '[GLM.BOOT] AppCheck skipped: $error');
      }
    }
  } else {
    glmTrace(
      () => '[GLM.BOOT] gate DISABLED — missing creds. White game only.',
    );
  }

  final sensor = ReachSensor();
  final push = PushBeacon(vault, enabled: productionServicesReady);
  final track = TrackRelay(agent);
  final router = OrbitRouter(
    vault: vault,
    sensor: sensor,
    track: track,
    call: ConfigCall(agent, vault),
    push: push,
    agent: agent,
    runtimeEnabled: OrbitConfig.grayCredentialsReady,
  );

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  runApp(SolarGleamApp(router: router));
}

class SolarGleamApp extends StatelessWidget {
  const SolarGleamApp({super.key, this.router});

  final OrbitRouter? router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Solar Gleam',
      debugShowCheckedModeBanner: false,
      theme: buildGleamTheme(),
      home: SplashScreen(router: router),
    );
  }
}
