import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'orbit/config/orbit_config.dart';
import 'orbit/net/config_call.dart';
import 'orbit/net/gleam_vault.dart';
import 'orbit/net/push_agent.dart';
import 'orbit/net/reach_sensor.dart';
import 'orbit/net/solar_agent.dart';
import 'orbit/net/signal_collector.dart';
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

  var servicesReady = false;
  if (OrbitConfig.credentialsReady) {
    try {
      await Firebase.initializeApp();
      servicesReady = true;
    } catch (_) {}
    if (servicesReady) {
      try {
        await FirebaseAppCheck.instance.activate(
          providerApple: kDebugMode
              ? const AppleDebugProvider()
              : const AppleAppAttestWithDeviceCheckFallbackProvider(),
        );
      } catch (_) {
        // App Check must never block messaging.
      }
    }
  }

  final sensor = ReachSensor();
  final push = PushAgent(vault, enabled: servicesReady);
  final track = SignalCollector(agent);
  final router = OrbitRouter(
    vault: vault,
    sensor: sensor,
    track: track,
    call: ConfigCall(agent, vault),
    push: push,
    agent: agent,
    runtimeEnabled: OrbitConfig.credentialsReady,
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
