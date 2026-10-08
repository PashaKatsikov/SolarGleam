import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_gleam/game/native_math.dart';
import 'package:solar_gleam/game/progress.dart';
import 'package:solar_gleam/screens/collection_screen.dart';
import 'package:solar_gleam/screens/level_select_screen.dart';
import 'package:solar_gleam/screens/main_menu_screen.dart';
import 'package:solar_gleam/screens/puzzle_screen.dart';
import 'package:solar_gleam/screens/restore_screen.dart';
import 'package:solar_gleam/screens/settings_screen.dart';
import 'package:solar_gleam/screens/world_map_screen.dart';
import 'package:solar_gleam/theme/neon_theme.dart';

import 'core_test.dart' show answerOf;

const _sizes = <String, Size>{
  'iPhone SE': Size(375, 667),
  'iPhone 18 Pro': Size(402, 874),
  'iPad Pro 13': Size(1032, 1376),
};

Future<void> _show(WidgetTester tester, Size size, Widget screen) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: buildNeonTheme(), home: screen));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final family in ['Oxanium', 'Cinzel']) {
      final loader = FontLoader(family)..addFont(rootBundle.load('assets/fonts/$family.ttf'));
      await loader.load();
    }
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Progress.instance.debugClear(2);
  });

  for (final entry in _sizes.entries) {
    group(entry.key, () {
      final size = entry.value;

      testWidgets('main menu', (tester) async {
        await _show(tester, size, const MainMenuScreen());
        expect(find.text('CONTINUE'), findsOneWidget);
        await _leave(tester);
      });

      testWidgets('world map', (tester) async {
        await _show(tester, size, const WorldMapScreen());
        expect(find.text('WORLDS'), findsOneWidget);
        await _leave(tester);
      });

      testWidgets('level select', (tester) async {
        await _show(tester, size, const LevelSelectScreen(region: 2));
        await _leave(tester);
      });

      testWidgets('collection', (tester) async {
        await _show(tester, size, const CollectionScreen());
        await tester.tap(find.text('MEMORIES'));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.text('RELICS'));
        await tester.pump(const Duration(milliseconds: 400));
        await _leave(tester);
      });

      testWidgets('settings', (tester) async {
        await _show(tester, size, const SettingsScreen());
        await _leave(tester);
      });

      testWidgets('puzzle with every rule shown', (tester) async {
        Progress.instance.tutorialBits = 31;
        for (final (r, l) in [(0, 0), (1, 5), (2, 3), (3, 7), (5, 7)]) {
          await _show(tester, size, PuzzleScreen(region: r, level: l));
          await tester.pump(const Duration(seconds: 6));
          await _leave(tester);
        }
      });

      testWidgets('rule tutorials', (tester) async {
        Progress.instance.tutorialBits = 0;
        await _show(tester, size, const PuzzleScreen(region: 3, level: 0));
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('GOT IT'), findsOneWidget);
        await _leave(tester);
      });

      testWidgets('restore', (tester) async {
        final spec = NativeMath.instance.start(1, 3)!;
        for (final orb in answerOf(spec)) {
          NativeMath.instance.tap(orb);
        }
        final reward = NativeMath.instance.finish(elapsedMs: 5000, repeat: false)!;
        final applied = Progress.instance.record(spec, reward);
        await _show(tester, size, RestoreScreen(applied: applied));
        await tester.pump(const Duration(seconds: 3));
        await _leave(tester);
      });
    });
  }
}
