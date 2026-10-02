import 'package:flutter_test/flutter_test.dart';
import 'package:solar_gleam/game/cheat_spins.dart';
import 'package:solar_gleam/game/slot_math.dart';

void main() {
  const bet = 200;

  List<List<SlotSymbol>> gridOf(SlotSymbol symbol) {
    return List.generate(reelCount, (_) => List.filled(rowCount, symbol));
  }

  test('payline count matches the engine', () {
    expect(paylines, hasLength(paylineCount));
    for (final line in paylines) {
      expect(line, hasLength(reelCount));
    }
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
      symbolDefs[SlotSymbol.crown]!.pay4 * (bet ~/ paylineCount),
    );
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
    expect(outcome.freeSpinsAwarded, freeSpinsFor3);
    expect(outcome.scatterWin, bet * scatterBetMultiplier3);
    expect(outcome.winningCells, contains(const Cell(0, 0)));
  });

  test('cheat grids land the requested win', () {
    final engine = SlotEngine();
    final solar = engine.evaluate(
      cheatGrid(CheatSpin.solarLine),
      totalBet: bet,
      freeSpin: false,
    );
    expect(
      solar.lineWins.any(
        (win) => win.symbol == SlotSymbol.solar && win.count == 4,
      ),
      isTrue,
    );

    final board = engine.evaluate(
      cheatGrid(CheatSpin.fullSolar),
      totalBet: bet,
      freeSpin: false,
    );
    expect(board.totalWin, greaterThan(bet * 30));

    final bonus = engine.evaluate(
      cheatGrid(CheatSpin.bonus4),
      totalBet: bet,
      freeSpin: false,
    );
    expect(bonus.scatterCount, 4);
    expect(bonus.freeSpinsAwarded, freeSpinsFor4);
  });

  test('free spins double the line win', () {
    final grid = gridOf(SlotSymbol.queen);
    final base = SlotEngine().evaluate(grid, totalBet: bet, freeSpin: false);
    final free = SlotEngine().evaluate(grid, totalBet: bet, freeSpin: true);
    expect(free.totalWin, base.totalWin * freeSpinLineMultiplier);
  });
}
