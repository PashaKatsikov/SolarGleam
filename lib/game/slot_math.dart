import 'dart:math';

import '../assets.dart';

enum SlotSymbol {
  ten,
  jack,
  queen,
  king,
  ace,
  star,
  fireball,
  chest,
  crown,
  solar,
  wild,
  bonus,
}

class SymbolDef {
  const SymbolDef({
    required this.name,
    required this.asset,
    required this.weight,
    required this.pay3,
    required this.pay4,
  });

  final String name;
  final String asset;
  final int weight;
  final int pay3;
  final int pay4;

  int linePay(int count) => count >= 4 ? pay4 : pay3;
}

const symbolDefs = <SlotSymbol, SymbolDef>{
  SlotSymbol.ten: SymbolDef(
    name: '10',
    asset: GleamAssets.ten,
    weight: 22,
    pay3: 14,
    pay4: 40,
  ),
  SlotSymbol.jack: SymbolDef(
    name: 'J',
    asset: GleamAssets.jack,
    weight: 18,
    pay3: 16,
    pay4: 50,
  ),
  SlotSymbol.queen: SymbolDef(
    name: 'Q',
    asset: GleamAssets.queen,
    weight: 16,
    pay3: 18,
    pay4: 60,
  ),
  SlotSymbol.king: SymbolDef(
    name: 'K',
    asset: GleamAssets.king,
    weight: 14,
    pay3: 22,
    pay4: 70,
  ),
  SlotSymbol.ace: SymbolDef(
    name: 'A',
    asset: GleamAssets.ace,
    weight: 12,
    pay3: 28,
    pay4: 90,
  ),
  SlotSymbol.star: SymbolDef(
    name: 'Solar Star',
    asset: GleamAssets.solarStar,
    weight: 7,
    pay3: 40,
    pay4: 140,
  ),
  SlotSymbol.fireball: SymbolDef(
    name: 'Fireball',
    asset: GleamAssets.fireball,
    weight: 6,
    pay3: 55,
    pay4: 200,
  ),
  SlotSymbol.chest: SymbolDef(
    name: 'Chest',
    asset: GleamAssets.chest,
    weight: 4,
    pay3: 80,
    pay4: 300,
  ),
  SlotSymbol.crown: SymbolDef(
    name: 'Crown',
    asset: GleamAssets.crown,
    weight: 3,
    pay3: 130,
    pay4: 500,
  ),
  SlotSymbol.solar: SymbolDef(
    name: 'Solar',
    asset: GleamAssets.solar,
    weight: 2,
    pay3: 210,
    pay4: 800,
  ),
  SlotSymbol.wild: SymbolDef(
    name: 'Wild',
    asset: GleamAssets.wild,
    weight: 3,
    pay3: 280,
    pay4: 1000,
  ),
  SlotSymbol.bonus: SymbolDef(
    name: 'Bonus',
    asset: GleamAssets.bonus,
    weight: 2,
    pay3: 0,
    pay4: 0,
  ),
};

const paytableOrder = <SlotSymbol>[
  SlotSymbol.wild,
  SlotSymbol.bonus,
  SlotSymbol.solar,
  SlotSymbol.crown,
  SlotSymbol.chest,
  SlotSymbol.fireball,
  SlotSymbol.star,
  SlotSymbol.ace,
  SlotSymbol.king,
  SlotSymbol.queen,
  SlotSymbol.jack,
  SlotSymbol.ten,
];

final List<SlotSymbol> symbolBag = [
  for (final entry in symbolDefs.entries)
    for (var i = 0; i < entry.value.weight; i++) entry.key,
];

const reelCount = 4;
const rowCount = 4;
const paylineCount = 20;

const paylines = <List<int>>[
  [0, 0, 0, 0],
  [1, 1, 1, 1],
  [2, 2, 2, 2],
  [3, 3, 3, 3],
  [0, 1, 2, 3],
  [3, 2, 1, 0],
  [0, 1, 1, 0],
  [3, 2, 2, 3],
  [1, 0, 0, 1],
  [2, 3, 3, 2],
  [1, 2, 2, 1],
  [2, 1, 1, 2],
  [0, 0, 1, 2],
  [3, 3, 2, 1],
  [1, 1, 2, 3],
  [2, 2, 1, 0],
  [0, 1, 0, 1],
  [3, 2, 3, 2],
  [1, 2, 1, 2],
  [2, 1, 2, 1],
];

const scatterBetMultiplier3 = 5;
const scatterBetMultiplier4 = 20;
const freeSpinsFor3 = 8;
const freeSpinsFor4 = 12;
const freeSpinLineMultiplier = 2;

class Cell {
  const Cell(this.reel, this.row);

  final int reel;
  final int row;

  @override
  bool operator ==(Object other) =>
      other is Cell && other.reel == reel && other.row == row;

  @override
  int get hashCode => Object.hash(reel, row);
}

class LineWin {
  const LineWin({
    required this.line,
    required this.symbol,
    required this.count,
    required this.amount,
  });

  final int line;
  final SlotSymbol symbol;
  final int count;
  final int amount;
}

class SpinOutcome {
  const SpinOutcome({
    required this.lineWins,
    required this.scatterCount,
    required this.scatterWin,
    required this.freeSpinsAwarded,
    required this.totalWin,
    required this.winningCells,
  });

  final List<LineWin> lineWins;
  final int scatterCount;
  final int scatterWin;
  final int freeSpinsAwarded;
  final int totalWin;
  final Set<Cell> winningCells;
}

class SlotEngine {
  SlotEngine({Random? random}) : _random = random ?? Random();

  final Random _random;

  SlotSymbol roll() => symbolBag[_random.nextInt(symbolBag.length)];

  List<List<SlotSymbol>> spinGrid() {
    return List.generate(
      reelCount,
      (_) => List.generate(rowCount, (_) => roll()),
    );
  }

  SpinOutcome evaluate(
    List<List<SlotSymbol>> grid, {
    required int totalBet,
    required bool freeSpin,
  }) {
    final lineBet = totalBet ~/ paylineCount;
    final wins = <LineWin>[];
    final cells = <Cell>{};
    var lineTotal = 0;

    for (var lineIndex = 0; lineIndex < paylines.length; lineIndex++) {
      final rows = paylines[lineIndex];
      final resolved = _resolveLine(grid, rows);
      if (resolved == null) continue;
      var amount =
          symbolDefs[resolved.symbol]!.linePay(resolved.count) * lineBet;
      if (freeSpin) amount *= freeSpinLineMultiplier;
      lineTotal += amount;
      wins.add(
        LineWin(
          line: lineIndex + 1,
          symbol: resolved.symbol,
          count: resolved.count,
          amount: amount,
        ),
      );
      for (var reel = 0; reel < resolved.count; reel++) {
        cells.add(Cell(reel, rows[reel]));
      }
    }

    var scatterCount = 0;
    final scatterCells = <Cell>[];
    for (var reel = 0; reel < reelCount; reel++) {
      for (var row = 0; row < rowCount; row++) {
        if (grid[reel][row] == SlotSymbol.bonus) {
          scatterCount++;
          scatterCells.add(Cell(reel, row));
        }
      }
    }

    var scatterWin = 0;
    var freeSpinsAwarded = 0;
    if (scatterCount >= 3) {
      final top = scatterCount >= 4;
      scatterWin =
          totalBet * (top ? scatterBetMultiplier4 : scatterBetMultiplier3);
      freeSpinsAwarded = top ? freeSpinsFor4 : freeSpinsFor3;
      cells.addAll(scatterCells);
    }

    return SpinOutcome(
      lineWins: wins,
      scatterCount: scatterCount,
      scatterWin: scatterWin,
      freeSpinsAwarded: freeSpinsAwarded,
      totalWin: lineTotal + scatterWin,
      winningCells: cells,
    );
  }

  _Resolved? _resolveLine(List<List<SlotSymbol>> grid, List<int> rows) {
    SlotSymbol? target;
    var count = 0;
    for (var reel = 0; reel < reelCount; reel++) {
      final symbol = grid[reel][rows[reel]];
      if (symbol == SlotSymbol.bonus) break;
      if (symbol == SlotSymbol.wild) {
        count++;
        continue;
      }
      if (target == null || symbol == target) {
        target ??= symbol;
        count++;
        continue;
      }
      break;
    }
    if (count < 3) return null;
    return _Resolved(target ?? SlotSymbol.wild, count);
  }
}

class _Resolved {
  const _Resolved(this.symbol, this.count);
  final SlotSymbol symbol;
  final int count;
}
