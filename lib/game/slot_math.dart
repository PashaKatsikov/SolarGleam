import '../assets.dart';
import 'native_math.dart';

/// Declaration order is the symbol id shared with the Rust math core.
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

/// Presentation only. Weights and pays live in the sealed Rust core.
class SymbolDef {
  const SymbolDef({required this.name, required this.asset});

  final String name;
  final String asset;
}

const symbolDefs = <SlotSymbol, SymbolDef>{
  SlotSymbol.ten: SymbolDef(name: '10', asset: GleamAssets.ten),
  SlotSymbol.jack: SymbolDef(name: 'J', asset: GleamAssets.jack),
  SlotSymbol.queen: SymbolDef(name: 'Q', asset: GleamAssets.queen),
  SlotSymbol.king: SymbolDef(name: 'K', asset: GleamAssets.king),
  SlotSymbol.ace: SymbolDef(name: 'A', asset: GleamAssets.ace),
  SlotSymbol.star: SymbolDef(name: 'Solar Star', asset: GleamAssets.solarStar),
  SlotSymbol.fireball: SymbolDef(name: 'Fireball', asset: GleamAssets.fireball),
  SlotSymbol.chest: SymbolDef(name: 'Chest', asset: GleamAssets.chest),
  SlotSymbol.crown: SymbolDef(name: 'Crown', asset: GleamAssets.crown),
  SlotSymbol.solar: SymbolDef(name: 'Solar', asset: GleamAssets.solar),
  SlotSymbol.wild: SymbolDef(name: 'Wild', asset: GleamAssets.wild),
  SlotSymbol.bonus: SymbolDef(name: 'Bonus', asset: GleamAssets.bonus),
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

/// Board shape. The math core is sealed for this layout.
const reelCount = 4;
const rowCount = 4;

/// Rule numbers read from the Rust core.
class SlotRules {
  const SlotRules._();

  static int get paylineCount => NativeMath.instance.constant(0);
  static int get scatterMultiplier3 => NativeMath.instance.constant(1);
  static int get scatterMultiplier4 => NativeMath.instance.constant(2);
  static int get freeSpinsFor3 => NativeMath.instance.constant(3);
  static int get freeSpinsFor4 => NativeMath.instance.constant(4);
  static int get freeSpinLineMultiplier => NativeMath.instance.constant(5);

  /// Pay for [count] of a kind on one line at the given per-line bet.
  static int linePay(SlotSymbol symbol, int count, int lineBet) =>
      NativeMath.instance.linePay(symbol.index, count, lineBet);
}

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
    required this.tier,
    required this.winningCells,
  });

  final List<LineWin> lineWins;
  final int scatterCount;
  final int scatterWin;
  final int freeSpinsAwarded;
  final int totalWin;

  /// 0 plain, 1 big win, 2 solar win. Thresholds are decided by the core.
  final int tier;
  final Set<Cell> winningCells;
}

/// Dart face of the Rust math core: every roll and payout is computed there.
class SlotEngine {
  SlotEngine() : _math = NativeMath.instance;

  final NativeMath _math;

  List<List<SlotSymbol>> spinGrid() {
    final flat = _math.spin();
    return List.generate(
      reelCount,
      (reel) => List.generate(
        rowCount,
        (row) => SlotSymbol.values[flat[reel * rowCount + row]],
      ),
    );
  }

  SpinOutcome evaluate(
    List<List<SlotSymbol>> grid, {
    required int totalBet,
    required bool freeSpin,
  }) {
    final flat = [
      for (var reel = 0; reel < reelCount; reel++)
        for (var row = 0; row < rowCount; row++) grid[reel][row].index,
    ];
    final words = _math.evaluate(flat, totalBet, freeSpin);

    final mask = words[5];
    final cells = <Cell>{
      for (var reel = 0; reel < reelCount; reel++)
        for (var row = 0; row < rowCount; row++)
          if ((mask >> (reel * rowCount + row)) & 1 == 1) Cell(reel, row),
    };
    final wins = <LineWin>[
      for (var i = 0; i < words[6]; i++)
        LineWin(
          line: words[7 + i * 4],
          symbol: SlotSymbol.values[words[8 + i * 4]],
          count: words[9 + i * 4],
          amount: words[10 + i * 4],
        ),
    ];
    return SpinOutcome(
      lineWins: wins,
      scatterCount: words[2],
      scatterWin: words[1],
      freeSpinsAwarded: words[3],
      totalWin: words[0],
      tier: words[4],
      winningCells: cells,
    );
  }
}
