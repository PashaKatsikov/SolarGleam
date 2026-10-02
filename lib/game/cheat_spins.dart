import 'package:flutter/material.dart';

import '../theme/gleam_theme.dart';
import 'slot_math.dart';

/// Temporary screenshot helper. Set to false to turn the cheat menu off.
const cheatMenuEnabled = false;

enum CheatSpin {
  solarLine('Solar x4'),
  wildLine('Wild x4'),
  crownLine('Crown x4'),
  chestLine('Chest x4'),
  fullSolar('Full Solar board'),
  fullWild('Full Wild board'),
  bonus3('Bonus x3'),
  bonus4('Bonus x4');

  const CheatSpin(this.label);
  final String label;
}

List<List<SlotSymbol>> cheatGrid(CheatSpin spin) {
  return switch (spin) {
    CheatSpin.solarLine => _line(SlotSymbol.solar),
    CheatSpin.wildLine => _line(SlotSymbol.wild),
    CheatSpin.crownLine => _line(SlotSymbol.crown),
    CheatSpin.chestLine => _line(SlotSymbol.chest),
    CheatSpin.fullSolar => _board(SlotSymbol.solar),
    CheatSpin.fullWild => _board(SlotSymbol.wild),
    CheatSpin.bonus3 => _bonus(3),
    CheatSpin.bonus4 => _bonus(4),
  };
}

List<List<SlotSymbol>> _board(SlotSymbol symbol) {
  return List.generate(reelCount, (_) => List.filled(rowCount, symbol));
}

List<List<SlotSymbol>> _filler() {
  const rows = <List<SlotSymbol>>[
    [SlotSymbol.ten, SlotSymbol.ace, SlotSymbol.star, SlotSymbol.fireball],
    [SlotSymbol.jack, SlotSymbol.ten, SlotSymbol.king, SlotSymbol.queen],
    [SlotSymbol.queen, SlotSymbol.jack, SlotSymbol.ace, SlotSymbol.ten],
    [SlotSymbol.king, SlotSymbol.queen, SlotSymbol.jack, SlotSymbol.chest],
  ];
  return List.generate(reelCount, (reel) {
    return List.generate(rowCount, (row) => rows[row][reel]);
  });
}

List<List<SlotSymbol>> _line(SlotSymbol symbol) {
  final grid = _filler();
  for (var reel = 0; reel < reelCount; reel++) {
    grid[reel][1] = symbol;
  }
  return grid;
}

List<List<SlotSymbol>> _bonus(int count) {
  final grid = _filler();
  const spots = <(int, int)>[(0, 0), (1, 2), (2, 0), (3, 3)];
  for (var i = 0; i < count; i++) {
    final (reel, row) = spots[i];
    grid[reel][row] = SlotSymbol.bonus;
  }
  return grid;
}

class CheatMenu extends StatelessWidget {
  const CheatMenu({super.key, required this.onPick, required this.onClose});

  final ValueChanged<CheatSpin> onPick;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return Material(
      color: const Color(0xC006040E),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 520,
                maxHeight: height * 0.86,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xF20C1022),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: GleamColors.gold, width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: Color(0x66F0A020), blurRadius: 28),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 8, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Cheat spin',
                              style: cinzel(22, GleamColors.goldLight),
                            ),
                          ),
                          IconButton(
                            onPressed: onClose,
                            icon: const Icon(
                              Icons.close,
                              color: GleamColors.gold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                        children: [
                          for (final spin in CheatSpin.values)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _CheatButton(
                                label: spin.label,
                                onPressed: () => onPick(spin),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CheatButton extends StatelessWidget {
  const _CheatButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE7A3), Color(0xFFF0C14B), Color(0xFFC8882B)],
        ),
        boxShadow: const [BoxShadow(color: Color(0x66F0A020), blurRadius: 12)],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                label,
                style: cinzel(16, GleamColors.ink, weight: 700),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
