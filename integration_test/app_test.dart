// Plays the real game on a simulator through the Rust core.
// Build with SG_PROBE=1 so the core can report the next correct orb:
//   SG_PROBE=1 flutter test integration_test/app_test.dart -d <simulator>
// Lines starting with SHOT: mark moments worth a screenshot.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:solar_gleam/audio/sound.dart';
import 'package:solar_gleam/game/game_settings.dart';
import 'package:solar_gleam/game/native_math.dart';
import 'package:solar_gleam/game/progress.dart';
import 'package:solar_gleam/screens/collection_screen.dart';
import 'package:solar_gleam/screens/level_select_screen.dart';
import 'package:solar_gleam/screens/main_menu_screen.dart';
import 'package:solar_gleam/screens/puzzle_screen.dart';
import 'package:solar_gleam/screens/settings_screen.dart';
import 'package:solar_gleam/screens/world_map_screen.dart';
import 'package:solar_gleam/theme/neon_theme.dart';
import 'package:solar_gleam/widgets/routes.dart';

final _nav = GlobalKey<NavigatorState>();
var _shots = 0;

Future<void> _wait(WidgetTester t, int ms) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _shot(WidgetTester t, String name, {int hold = 2200, int before = 0}) async {
  if (before > 0) await _wait(t, before);
  _shots++;
  File('/tmp/sg_marker.txt').writeAsStringSync('$_shots:$name', flush: true);
  await _wait(t, hold);
}

Future<bool> _until(WidgetTester t, bool Function() ok, {int maxMs = 90000}) async {
  final end = DateTime.now().add(Duration(milliseconds: maxMs));
  while (DateTime.now().isBefore(end)) {
    if (ok()) return true;
    await t.pump(const Duration(milliseconds: 100));
  }
  return false;
}

bool _inputPhase() =>
    find.text('YOUR TURN').evaluate().isNotEmpty ||
    find.text('TAP IN REVERSE ORDER').evaluate().isNotEmpty ||
    find.text('TAP THE MATCHING ORBS').evaluate().isNotEmpty;

Future<void> _push(WidgetTester t, Widget page) async {
  _nav.currentState!.push(softRoute(page));
  await _wait(t, 700);
}

Future<void> _back(WidgetTester t) async {
  _nav.currentState!.pop();
  await _wait(t, 600);
}

Future<void> _dismissTutorials(WidgetTester t, {String? shotPrefix}) async {
  var n = 0;
  while (find.text('GOT IT').evaluate().isNotEmpty) {
    if (shotPrefix != null) await _shot(t, '${shotPrefix}_tutorial$n', hold: 3400);
    await t.tap(find.text('GOT IT'));
    await _wait(t, 600);
    n++;
  }
}

/// Taps the whole answer using the core's probe.
Future<void> _solve(WidgetTester t, {String? shotPrefix}) async {
  final core = NativeMath.instance;
  expect(core.hasProbe, isTrue, reason: 'build with SG_PROBE=1');
  expect(await _until(t, _inputPhase), isTrue, reason: 'input phase never started');
  if (shotPrefix != null) await _shot(t, '${shotPrefix}_input', hold: 1200);
  var guard = 0;
  while (guard++ < 40) {
    final next = core.probeNext();
    if (next < 0) break;
    await t.tap(find.byKey(ValueKey('orb$next')));
    await _wait(t, 260);
    if (find.text('LEVELS').evaluate().isNotEmpty) break;
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('play through the game', (t) async {
    Sound.instance.enabled = false;
    await GameSettings.instance.load();
    await Progress.instance.reset();

    await t.pumpWidget(
      MaterialApp(
        navigatorKey: _nav,
        theme: buildNeonTheme(),
        debugShowCheckedModeBanner: false,
        home: const MainMenuScreen(),
      ),
    );
    await _shot(t, 'menu_new');

    // First puzzle by tapping PLAY like a player.
    await t.tap(find.text('PLAY'));
    await _wait(t, 900);
    await _shot(t, 'tutorial_echo_first', hold: 3500);
    await _dismissTutorials(t);
    await _wait(t, 1300);
    await _shot(t, 'puzzle_watch', hold: 400);
    await _solve(t, shotPrefix: 'puzzle_r0l0');
    await _wait(t, 600);
    await _shot(t, 'solved_flash', hold: 600);
    expect(await _until(t, () => find.text('LEVELS').evaluate().isNotEmpty), isTrue);
    await _shot(t, 'restore_a', before: 3000, hold: 800);

    // Next level through the real button.
    await t.tap(find.text('NEXT LEVEL'));
    await _wait(t, 900);
    await _dismissTutorials(t);
    await _solve(t);
    expect(await _until(t, () => find.text('LEVELS').evaluate().isNotEmpty), isTrue);
    await _shot(t, 'restore_b', before: 3000, hold: 800);

    // Jump to the later regions so every rule is seen.
    _nav.currentState!.popUntil((r) => r.isFirst);
    await _wait(t, 600);
    Progress.instance.debugClear(5);
    await _shot(t, 'menu_late', hold: 1800);
    await _push(t, const WorldMapScreen());
    await _shot(t, 'world_map');
    await _back(t);

    for (final (region, level, tag) in [(2, 3, 'r2l3'), (3, 4, 'r3l4'), (5, 7, 'r5l7')]) {
      await _push(t, PuzzleScreen(region: region, level: level));
      await _wait(t, 500);
      await _dismissTutorials(t, shotPrefix: tag);
      await _wait(t, 2500);
      await _shot(t, '${tag}_preview', hold: 900);
      await _solve(t, shotPrefix: tag);
      expect(await _until(t, () => find.text('LEVELS').evaluate().isNotEmpty), isTrue);
      await _shot(t, '${tag}_restore', before: 3200, hold: 800);
      _nav.currentState!.popUntil((r) => r.isFirst);
      await _wait(t, 600);
    }

    // Failure and pause overlays.
    await _push(t, const PuzzleScreen(region: 0, level: 0));
    await _dismissTutorials(t);
    expect(await _until(t, _inputPhase), isTrue);
    final wrong = (NativeMath.instance.probeNext() + 1) % 3;
    for (var i = 0; i < 8; i++) {
      if (find.text('SIGNAL LOST').evaluate().isNotEmpty) break;
      await t.tap(find.byKey(ValueKey('orb${(NativeMath.instance.probeNext() + 1 + (i + wrong) % 2) % 3}')));
      await _wait(t, 450);
      if (i == 0) await _shot(t, 'wrong_tap', hold: 500);
    }
    await _shot(t, 'failed');
    _nav.currentState!.popUntil((r) => r.isFirst);
    await _wait(t, 600);

    await _push(t, const PuzzleScreen(region: 1, level: 2));
    await _dismissTutorials(t);
    await _wait(t, 800);
    await t.tap(find.byIcon(Icons.pause_rounded));
    await _wait(t, 500);
    await _shot(t, 'pause');
    await t.tap(find.text('RESUME'));
    await _wait(t, 500);
    expect(await _until(t, _inputPhase), isTrue);
    await t.tap(find.byIcon(Icons.lightbulb_rounded));
    await _wait(t, 500);
    await _shot(t, 'hint', hold: 900);
    _nav.currentState!.popUntil((r) => r.isFirst);
    await _wait(t, 600);

    await _push(t, const LevelSelectScreen(region: 2));
    await _shot(t, 'levels_r2');
    await _back(t);
    await _push(t, const CollectionScreen());
    await _shot(t, 'collection_orbs');
    await t.tap(find.text('MEMORIES'));
    await _shot(t, 'collection_memories', hold: 1200);
    await t.tap(find.text('RELICS'));
    await _shot(t, 'collection_relics', hold: 1200);
    await _back(t);
    await _push(t, const SettingsScreen());
    await _shot(t, 'settings');
    await t.drag(find.byType(ListView).first, const Offset(0, -500));
    await _shot(t, 'settings_b', hold: 1000);
    await _back(t);
    await _shot(t, 'done', hold: 300);
  });
}
