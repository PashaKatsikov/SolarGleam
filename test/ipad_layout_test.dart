import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_gleam/screens/game_screen.dart';
import 'package:solar_gleam/screens/splash_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpAt(WidgetTester tester, Size physical, Widget home) async {
    tester.view.physicalSize = physical;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  testWidgets('iPad portrait loading keeps the screen intact', (tester) async {
    await pumpAt(tester, const Size(2064, 2752), const SplashScreen());
    expect(find.text('LOADING'), findsOneWidget);
  });

  testWidgets('iPad landscape loading keeps the screen intact', (tester) async {
    await pumpAt(tester, const Size(2752, 2064), const SplashScreen());
    expect(find.text('LOADING'), findsOneWidget);
  });

  testWidgets('iPad game shows a larger logo and the hud', (tester) async {
    await pumpAt(tester, const Size(2064, 2752), const GameScreen());
    expect(find.text('BALANCE'), findsOneWidget);
    expect(find.text('WIN'), findsOneWidget);
  });
}
