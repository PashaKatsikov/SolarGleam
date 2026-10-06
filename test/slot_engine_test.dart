import 'package:flutter_test/flutter_test.dart';
import 'package:solar_gleam/game/slot_math.dart';

// These tests run against the Rust core through FFI. Build the host library
// first:  cd rust/solar_math && cargo build --release
void main() {
  const bet = 200;

  List<List<SlotSymbol>> gridOf(SlotSymbol symbol) {
    return List.generate(reelCount, (_) => List.filled(rowCount, symbol));
  }

  test('the core reports its rules', () {
    expect(SlotRules.paylineCount, 20);
    expect(SlotRules.freeSpinsFor3, 8);
    expect(SlotRules.freeSpinsFor4, 12);
    expect(SlotRules.scatterMultiplier3, 5);
    expect(SlotRules.scatterMultiplier4, 20);
    expect(SlotRules.freeSpinLineMultiplier, 2);
  });

  test('random grids stay on the board and use every symbol over time', () {
    final engine = SlotEngine();
    final seen = <SlotSymbol>{};
    for (var i = 0; i < 400; i++) {
      final grid = engine.spinGrid();
      expect(grid, hasLength(reelCount));
      for (final reel in grid) {
        expect(reel, hasLength(rowCount));
        seen.addAll(reel);
      }
    }
    expect(seen, containsAll(SlotSymbol.values));
  });

  test('wild completes a crown line from the left', () {
    final grid = gridOf(SlotSymbol.ten);
    grid[0][0] = SlotSymbol.wild;
    grid[1][0] = SlotSymbol.wild;
    grid[2][0] = SlotSymbol.crown;
    grid[3][0] = SlotSymbol.crown;

    final outcome = SlotEngine().evaluate(grid, totalBet: bet, freeSpin: false);
    final crown = outcome.lineWins.where(
      (win) => win.symbol == SlotSymbol.crown && win.count == 4,
    );
    expect(crown, isNotEmpty);
    expect(
      crown.first.amount,
      SlotRules.linePay(SlotSymbol.crown, 4, bet ~/ SlotRules.paylineCount),
    );
    expect(crown.first.amount, greaterThan(0));
  });

  test('bonus does not substitute on a payline', () {
    final grid = gridOf(SlotSymbol.jack);
    grid[0][0] = SlotSymbol.bonus;
    grid[1][0] = SlotSymbol.solar;
    grid[2][0] = SlotSymbol.solar;
    grid[3][0] = SlotSymbol.solar;

    final outcome = SlotEngine().evaluate(grid, totalBet: bet, freeSpin: false);
    expect(
      outcome.lineWins.where(
        (win) => win.line == 1 && win.symbol == SlotSymbol.solar,
      ),
      isEmpty,
    );
  });

  test('three bonus symbols award free spins and a scatter prize', () {
    final grid = gridOf(SlotSymbol.ace);
    grid[0][0] = SlotSymbol.bonus;
    grid[1][1] = SlotSymbol.bonus;
    grid[2][2] = SlotSymbol.bonus;

    final outcome = SlotEngine().evaluate(grid, totalBet: bet, freeSpin: false);
    expect(outcome.scatterCount, 3);
    expect(outcome.freeSpinsAwarded, SlotRules.freeSpinsFor3);
    expect(outcome.scatterWin, bet * SlotRules.scatterMultiplier3);
    expect(outcome.winningCells, contains(const Cell(0, 0)));
  });

  test('a solar line, a full solar board and four bonuses pay out', () {
    final engine = SlotEngine();
    final line = gridOf(SlotSymbol.ten);
    for (var reel = 0; reel < reelCount; reel++) {
      line[reel][1] = SlotSymbol.solar;
    }
    final solar = engine.evaluate(line, totalBet: bet, freeSpin: false);
    expect(
      solar.lineWins.any(
        (win) => win.symbol == SlotSymbol.solar && win.count == 4,
      ),
      isTrue,
    );

    final board = engine.evaluate(
      gridOf(SlotSymbol.solar),
      totalBet: bet,
      freeSpin: false,
    );
    expect(board.totalWin, greaterThan(bet * 30));
    expect(board.tier, 2);

    final scatter = gridOf(SlotSymbol.ten);
    for (final (reel, row) in const [(0, 0), (1, 2), (2, 0), (3, 3)]) {
      scatter[reel][row] = SlotSymbol.bonus;
    }
    final bonus = engine.evaluate(scatter, totalBet: bet, freeSpin: false);
    expect(bonus.scatterCount, 4);
    expect(bonus.freeSpinsAwarded, SlotRules.freeSpinsFor4);
  });

  test('free spins double the line win', () {
    final grid = gridOf(SlotSymbol.queen);
    final base = SlotEngine().evaluate(grid, totalBet: bet, freeSpin: false);
    final free = SlotEngine().evaluate(grid, totalBet: bet, freeSpin: true);
    expect(free.totalWin, base.totalWin * SlotRules.freeSpinLineMultiplier);
  });
}
