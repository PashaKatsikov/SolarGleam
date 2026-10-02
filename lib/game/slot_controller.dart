import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/gleam_theme.dart';
import 'gleam_settings.dart';
import 'slot_math.dart';

enum SpinPhase { idle, spinning, presenting }

class SlotController extends ChangeNotifier {
  SlotController({SlotEngine? engine}) : engine = engine ?? SlotEngine() {
    grid = this.engine.spinGrid();
  }

  static const bets = <int>[100, 200, 500, 1000, 2000, 5000];
  static const startingGleam = 10000;
  static const _balanceKey = 'gleam_balance';
  static const _betKey = 'gleam_bet_index';

  final SlotEngine engine;

  late List<List<SlotSymbol>> grid;
  int balance = startingGleam;
  int betIndex = 1;
  int spinId = 0;
  SpinPhase phase = SpinPhase.idle;
  bool autoplay = false;
  bool rush = false;
  bool paused = false;
  bool needsRefill = false;
  int freeSpins = 0;
  int shownWin = 0;
  String message = '20 paylines';
  String? celebrationTitle;
  Set<Cell> winningCells = {};

  bool _busy = false;
  bool _disposed = false;
  bool _wasFree = false;
  bool _holdAfterSpin = false;
  int _chargedBet = bets[1];
  List<List<SlotSymbol>>? _forcedGrid;
  Timer? _presentTimer;
  Timer? _watchdog;

  int get bet => bets[betIndex];
  bool get spinning => phase == SpinPhase.spinning;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_disposed) return;
      balance = prefs.getInt(_balanceKey) ?? startingGleam;
      final storedBet = prefs.getInt(_betKey) ?? betIndex;
      betIndex = storedBet.clamp(0, bets.length - 1);
      if (balance < bets.first && freeSpins == 0) {
        balance = startingGleam;
      }
      notifyListeners();
    } catch (_) {
      // Keep the starting balance when storage is unavailable.
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_balanceKey, balance);
    await prefs.setInt(_betKey, betIndex);
  }

  void changeBet(int direction) {
    if (spinning || freeSpins > 0) return;
    final next = betIndex + direction;
    if (next < 0 || next >= bets.length) return;
    betIndex = next;
    GleamSettings.instance.selection();
    notifyListeners();
    save();
  }

  void toggleAuto() {
    autoplay = !autoplay;
    GleamSettings.instance.selection();
    notifyListeners();
    if (autoplay && phase == SpinPhase.idle && !paused) {
      onSpinPressed();
    }
  }

  void setPaused(bool value) {
    paused = value;
    if (value) {
      autoplay = false;
    }
    notifyListeners();
    if (!value && phase == SpinPhase.idle && freeSpins > 0) {
      onSpinPressed();
    }
  }

  void refill() {
    balance = startingGleam;
    needsRefill = false;
    message = 'The vault restored 10,000 gleam';
    notifyListeners();
    save();
  }

  void dismissRefill() {
    needsRefill = false;
    notifyListeners();
  }

  void playForced(List<List<SlotSymbol>> forced) {
    if (_disposed || phase == SpinPhase.spinning) return;
    _forcedGrid = [for (final reel in forced) List<SlotSymbol>.from(reel)];
    _holdAfterSpin = true;
    autoplay = false;
    needsRefill = false;
    if (balance < bet) balance = startingGleam;
    onSpinPressed();
  }

  void onSpinPressed() {
    if (phase == SpinPhase.spinning) {
      if (!rush) {
        rush = true;
        notifyListeners();
      }
      return;
    }
    if (phase == SpinPhase.presenting) {
      _finishPresentation(continuePlay: false);
    }
    unawaited(_spin());
  }

  Future<void> _spin() async {
    if (_busy || paused) return;
    final free = freeSpins > 0;
    if (!free && balance < bet) {
      autoplay = false;
      needsRefill = true;
      message = 'Not enough gleam';
      notifyListeners();
      return;
    }

    _busy = true;
    rush = false;
    _wasFree = free;
    _chargedBet = bet;
    if (free) {
      freeSpins -= 1;
    } else {
      balance -= bet;
    }
    final forced = _forcedGrid;
    _forcedGrid = null;
    grid = forced ?? engine.spinGrid();
    winningCells = {};
    shownWin = 0;
    celebrationTitle = null;
    message = free ? 'Free spin' : 'The reels are turning';
    phase = SpinPhase.spinning;
    spinId += 1;
    GleamSettings.instance.medium();
    notifyListeners();
    save();

    _watchdog?.cancel();
    _watchdog = Timer(const Duration(seconds: 6), () {
      if (phase == SpinPhase.spinning) onReelsSettled();
    });
  }

  void onReelsSettled() {
    if (phase != SpinPhase.spinning) return;
    _watchdog?.cancel();
    final outcome = engine.evaluate(
      grid,
      totalBet: _chargedBet,
      freeSpin: _wasFree,
    );
    balance += outcome.totalWin;
    freeSpins += outcome.freeSpinsAwarded;
    shownWin = outcome.totalWin;
    winningCells = outcome.winningCells;
    celebrationTitle = _celebration(outcome);
    message = _message(outcome);
    phase = SpinPhase.presenting;
    if (outcome.totalWin >= _chargedBet * 15) {
      GleamSettings.instance.heavy();
    }
    notifyListeners();
    save();

    final wait = outcome.totalWin <= 0
        ? 380
        : outcome.freeSpinsAwarded > 0 || outcome.totalWin >= _chargedBet * 15
        ? 1900
        : 1300;
    _presentTimer?.cancel();
    _presentTimer = Timer(Duration(milliseconds: wait), () {
      _finishPresentation(continuePlay: true);
    });
  }

  void _finishPresentation({required bool continuePlay}) {
    _presentTimer?.cancel();
    if (phase != SpinPhase.presenting) return;
    phase = SpinPhase.idle;
    _busy = false;
    notifyListeners();
    if (!continuePlay || paused) return;
    if (_holdAfterSpin) {
      _holdAfterSpin = false;
      return;
    }
    if (freeSpins > 0 || autoplay) {
      onSpinPressed();
    }
  }

  String? _celebration(SpinOutcome outcome) {
    if (outcome.freeSpinsAwarded > 0) return 'FREE SPINS';
    if (outcome.totalWin >= _chargedBet * 30) return 'SOLAR WIN';
    if (outcome.totalWin >= _chargedBet * 15) return 'BIG WIN';
    return null;
  }

  String _message(SpinOutcome outcome) {
    if (outcome.freeSpinsAwarded > 0) {
      final prize = outcome.totalWin > 0
          ? ' · ${formatGleam(outcome.totalWin)} gleam'
          : '';
      return '${outcome.freeSpinsAwarded} free spins awarded$prize';
    }
    if (outcome.totalWin <= 0) {
      return freeSpins > 0 ? 'Free spins left: $freeSpins' : 'No win';
    }
    final best = outcome.lineWins.isEmpty
        ? null
        : outcome.lineWins.reduce((a, b) => a.amount >= b.amount ? a : b);
    final title = celebrationTitle == null ? 'Won' : celebrationTitle!;
    if (best == null) return '$title ${formatGleam(outcome.totalWin)} gleam';
    final name = symbolDefs[best.symbol]!.name;
    return '$title ${formatGleam(outcome.totalWin)} gleam · $name x${best.count}';
  }

  @override
  void dispose() {
    _disposed = true;
    _presentTimer?.cancel();
    _watchdog?.cancel();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }
}
