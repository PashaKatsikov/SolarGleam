import 'dart:math';

import 'package:flutter/material.dart';

import '../assets.dart';
import '../game/slot_math.dart';

class FrameGrid {
  static const columns = <List<double>>[
    [396 / 1547, 557 / 1547],
    [592 / 1547, 756 / 1547],
    [791 / 1547, 956 / 1547],
    [990 / 1547, 1151 / 1547],
  ];

  static const rows = <List<double>>[
    [484 / 1513, 625 / 1513],
    [660 / 1513, 805 / 1513],
    [840 / 1513, 988 / 1513],
    [1022 / 1513, 1180 / 1513],
  ];
}

class ReelBoard extends StatefulWidget {
  const ReelBoard({
    super.key,
    required this.grid,
    required this.spinId,
    required this.spinning,
    required this.rush,
    required this.winningCells,
    required this.showWins,
    required this.onSettled,
    required this.onTap,
  });

  final List<List<SlotSymbol>> grid;
  final int spinId;
  final bool spinning;
  final bool rush;
  final Set<Cell> winningCells;
  final bool showWins;
  final VoidCallback onSettled;
  final VoidCallback onTap;

  @override
  State<ReelBoard> createState() => _ReelBoardState();
}

class _ReelBoardState extends State<ReelBoard> {
  int _arrived = 0;
  int _trackedSpin = -1;

  void _reelArrived() {
    if (_trackedSpin != widget.spinId) {
      _trackedSpin = widget.spinId;
      _arrived = 0;
    }
    _arrived += 1;
    if (_arrived >= reelCount) widget.onSettled();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            GleamAssets.slotFrame,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
          ),
          for (var reel = 0; reel < reelCount; reel++)
            Positioned.fill(
              child: _ReelColumn(
                key: ValueKey('reel-$reel'),
                reelIndex: reel,
                landing: widget.grid[reel],
                spinId: widget.spinId,
                spinning: widget.spinning,
                rush: widget.rush,
                winningCells: widget.winningCells,
                showWins: widget.showWins,
                onSettled: _reelArrived,
              ),
            ),
        ],
      ),
    );
  }
}

class _ReelColumn extends StatefulWidget {
  const _ReelColumn({
    super.key,
    required this.reelIndex,
    required this.landing,
    required this.spinId,
    required this.spinning,
    required this.rush,
    required this.winningCells,
    required this.showWins,
    required this.onSettled,
  });

  final int reelIndex;
  final List<SlotSymbol> landing;
  final int spinId;
  final bool spinning;
  final bool rush;
  final Set<Cell> winningCells;
  final bool showWins;
  final VoidCallback onSettled;

  @override
  State<_ReelColumn> createState() => _ReelColumnState();
}

class _ReelColumnState extends State<_ReelColumn>
    with SingleTickerProviderStateMixin {
  static const _curve = _ReelCurve();

  late final AnimationController _controller;
  List<SlotSymbol> _strip = const [];
  int _steps = 0;
  int _token = 0;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _showLanded();
    if (widget.spinning) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.spinning) _startSpin();
      });
    }
  }

  @override
  void didUpdateWidget(covariant _ReelColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spinId != oldWidget.spinId && widget.spinning) {
      _startSpin();
    } else if (widget.rush && !oldWidget.rush && _controller.isAnimating) {
      _rush();
    } else if (widget.landing != oldWidget.landing && !widget.spinning) {
      _showLanded();
    }
  }

  void _showLanded() {
    _steps = 0;
    _strip = [...widget.landing, widget.landing.last];
    _controller.value = 1;
  }

  void _startSpin() {
    final token = ++_token;
    _reported = false;
    final steps = 12 + widget.reelIndex * 3;
    final random = Random(widget.spinId * 97 + widget.reelIndex * 13);
    _steps = steps;
    _strip = [
      for (var i = 0; i < steps; i++)
        SlotSymbol.values[random.nextInt(SlotSymbol.values.length)],
      ...widget.landing,
      widget.landing.last,
    ];
    _controller.duration = Duration(
      milliseconds: 1080 + widget.reelIndex * 250,
    );
    _controller.forward(from: 0).whenComplete(() => _report(token));
    if (widget.rush) _rush();
  }

  void _rush() {
    final token = _token;
    _controller
        .animateTo(
          1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        )
        .whenComplete(() => _report(token));
  }

  void _report(int token) {
    if (!mounted || _reported || token != _token) return;
    if (_controller.value < 0.999) return;
    _reported = true;
    widget.onSettled();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final shift = _steps * _curve.transform(_controller.value.clamp(0, 1));
        final base = shift.floor();
        final fraction = shift - base;
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final column = FrameGrid.columns[widget.reelIndex];
            return Stack(
              children: [
                for (var row = 0; row < rowCount; row++)
                  _cell(
                    width: width,
                    height: height,
                    row: row,
                    left: column[0],
                    right: column[1],
                    base: base,
                    fraction: fraction,
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _cell({
    required double width,
    required double height,
    required int row,
    required double left,
    required double right,
    required int base,
    required double fraction,
  }) {
    final band = FrameGrid.rows[row];
    final top = band[0] * height;
    final cellHeight = (band[1] - band[0]) * height;
    final cellWidth = (right - left) * width;
    final win =
        widget.showWins &&
        widget.winningCells.contains(Cell(widget.reelIndex, row));
    final topSymbol = _strip[(base + row).clamp(0, _strip.length - 1)];
    final nextSymbol = _strip[(base + row + 1).clamp(0, _strip.length - 1)];

    return Positioned(
      left: left * width,
      top: top,
      width: cellWidth,
      height: cellHeight,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minWidth: cellWidth,
          maxWidth: cellWidth,
          minHeight: cellHeight * 2,
          maxHeight: cellHeight * 2,
          child: Transform.translate(
            offset: Offset(0, -fraction * cellHeight),
            child: Column(
              children: [
                SizedBox(
                  width: cellWidth,
                  height: cellHeight,
                  child: _SymbolArt(
                    symbol: topSymbol,
                    winning: win && fraction < 0.45,
                  ),
                ),
                SizedBox(
                  width: cellWidth,
                  height: cellHeight,
                  child: _SymbolArt(
                    symbol: nextSymbol,
                    winning: win && fraction >= 0.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SymbolArt extends StatelessWidget {
  const _SymbolArt({required this.symbol, required this.winning});

  final SlotSymbol symbol;
  final bool winning;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (winning)
            const DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0xE6FFE08A), Color(0x00FFE08A)],
                ),
              ),
            ),
          Image.asset(
            symbolDefs[symbol]!.asset,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
          ),
        ],
      ),
    );
  }
}

class _ReelCurve extends Curve {
  const _ReelCurve();

  @override
  double transformInternal(double t) {
    if (t < 0.62) return (t / 0.62) * 0.8;
    final eased = Curves.easeOutCubic.transform((t - 0.62) / 0.38);
    return 0.8 + 0.2 * eased;
  }
}
