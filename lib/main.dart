import 'dart:async';

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

  // Firebase core is brought up off the first-frame path and is the only thing
  // messaging (and the cold-launch push link) waits on — it resolves in a few
  // hundred ms. App Check is activated separately, in the background: its App
  // Attest provider does a real attestation round-trip that can take seconds or
  // stall on a bad network, and nothing on the push path needs it, so it must
  // never gate opening the tapped link.
  final firebaseReady = _initFirebase();

  final sensor = ReachSensor();
  final push = PushAgent(vault, ready: firebaseReady);
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

/// Brings up Firebase core and returns whether messaging is usable. App Check
/// is started in the background and is deliberately not part of the returned
/// future, so callers that need messaging never wait on attestation.
Future<bool> _initFirebase() async {
  if (!OrbitConfig.credentialsReady) return false;
  try {
    await Firebase.initializeApp();
  } catch (_) {
    return false;
  }
  unawaited(_activateAppCheck());
  return true;
}

Future<void> _activateAppCheck() async {
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
