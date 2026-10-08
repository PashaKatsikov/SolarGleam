import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/splash_screen.dart';
import 'theme/neon_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  runApp(const SolarGleamApp());
}

class SolarGleamApp extends StatelessWidget {
  const SolarGleamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Solar Gleam',
      debugShowCheckedModeBanner: false,
      theme: buildNeonTheme(),
      home: const SplashScreen(),
    );
  }
}
