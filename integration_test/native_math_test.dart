import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:solar_gleam/game/slot_math.dart';

// Runs on a simulator or device: proves the Rust core is linked into the app.
//   flutter test integration_test -d <device id>
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the linked Rust core spins and pays', (tester) async {
    expect(SlotRules.paylineCount, 20);

    final engine = SlotEngine();
    final grid = engine.spinGrid();
    expect(grid, hasLength(reelCount));

    final solar = List.generate(
      reelCount,
      (_) => List.filled(rowCount, SlotSymbol.solar),
    );
    final outcome = engine.evaluate(solar, totalBet: 200, freeSpin: false);
    expect(outcome.lineWins, hasLength(SlotRules.paylineCount));
    expect(outcome.tier, 2);
    expect(outcome.totalWin, greaterThan(200 * 30));
  });
}
