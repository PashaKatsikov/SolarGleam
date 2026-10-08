import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'native_math.dart';
import 'world_data.dart';

/// What a cleared puzzle changed, for the result screens.
class Applied {
  const Applied({
    required this.reward,
    required this.newOrbs,
    required this.decor,
    required this.regionDone,
    required this.firstClear,
    required this.bestStars,
    required this.spec,
  });

  final RewardSpec reward;
  final PuzzleSpec spec;
  final List<int> newOrbs;

  /// Decor piece earned, as (region, index), or null.
  final (int, int)? decor;
  final bool regionDone;
  final bool firstClear;
  final int bestStars;
}

class Progress extends ChangeNotifier {
  Progress._();

  static final instance = Progress._();
  static const _key = 'nm_progress_v1';

  static const regions = 6;
  static const levels = 8;

  final List<List<int>> stars = List.generate(regions, (_) => List.filled(levels, 0));
  int energy = 0;
  int totalEnergy = 0;
  int solved = 0;
  int flawless = 0;
  int fastSolves = 0;
  int tutorialBits = 0;
  final Set<int> orbs = {};
  final Set<int> decor = {};
  final Set<int> openRegions = {0};

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final rows = data['stars'] as List<dynamic>;
      for (var r = 0; r < regions && r < rows.length; r++) {
        final row = rows[r] as List<dynamic>;
        for (var l = 0; l < levels && l < row.length; l++) {
          stars[r][l] = (row[l] as int).clamp(0, 3);
        }
      }
      energy = data['energy'] as int? ?? 0;
      totalEnergy = data['total'] as int? ?? 0;
      solved = data['solved'] as int? ?? 0;
      flawless = data['flawless'] as int? ?? 0;
      fastSolves = data['fast'] as int? ?? 0;
      tutorialBits = data['tutorial'] as int? ?? 0;
      orbs
        ..clear()
        ..addAll((data['orbs'] as List<dynamic>? ?? const []).cast<int>());
      decor
        ..clear()
        ..addAll((data['decor'] as List<dynamic>? ?? const []).cast<int>());
      openRegions
        ..clear()
        ..add(0)
        ..addAll((data['open'] as List<dynamic>? ?? const []).cast<int>());
      notifyListeners();
    } catch (_) {
      // A damaged save starts a fresh journey instead of crashing.
    }
  }

  Future<void> _save() async {
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'stars': stars,
          'energy': energy,
          'total': totalEnergy,
          'solved': solved,
          'flawless': flawless,
          'fast': fastSolves,
          'tutorial': tutorialBits,
          'orbs': orbs.toList()..sort(),
          'decor': decor.toList()..sort(),
          'open': openRegions.toList()..sort(),
        }),
      );
    } catch (_) {}
  }

  // Queries -------------------------------------------------------------------

  bool regionOpen(int r) => openRegions.contains(r);

  int cleared(int r) => stars[r].where((s) => s > 0).length;

  int starsIn(int r) => stars[r].fold(0, (a, b) => a + b);

  bool regionComplete(int r) => cleared(r) == levels;

  int get totalCleared => List.generate(regions, cleared).fold(0, (a, b) => a + b);

  int get totalStars => List.generate(regions, starsIn).fold(0, (a, b) => a + b);

  int get regionsComplete => List.generate(regions, regionComplete).where((c) => c).length;

  bool levelOpen(int r, int l) => regionOpen(r) && (l == 0 || stars[r][l - 1] > 0);

  /// Restored objects of a region as a bit mask over its eight slots.
  int restoredMask(int r) {
    var mask = 0;
    for (var l = 0; l < levels; l++) {
      if (stars[r][l] > 0) mask |= 1 << l;
    }
    return mask;
  }

  int decorMask(int r) {
    var mask = 0;
    for (var i = 0; i < 4; i++) {
      if (decor.contains(r * 4 + i)) mask |= 1 << i;
    }
    return mask;
  }

  bool memoryUnlocked(int r) => regionComplete(r);

  /// Next puzzle to play: the first unfinished level of an open region.
  (int, int)? get nextLevel {
    for (var r = 0; r < regions; r++) {
      if (!regionOpen(r)) continue;
      for (var l = 0; l < levels; l++) {
        if (stars[r][l] == 0) return (r, l);
      }
    }
    return null;
  }

  bool get finished => regionsComplete == regions;

  double get worldPercent => totalCleared / (regions * levels);

  bool tutorialSeen(int bit) => tutorialBits & bit != 0;

  // Changes -------------------------------------------------------------------

  Future<void> markTutorial(int bit) {
    tutorialBits |= bit;
    return _save();
  }

  Future<void> forgetTutorials() {
    tutorialBits = 0;
    return _save();
  }

  Applied record(PuzzleSpec spec, RewardSpec reward) {
    final r = spec.region;
    final l = spec.level;
    final firstClear = stars[r][l] == 0;
    if (reward.stars > stars[r][l]) stars[r][l] = reward.stars;

    energy += reward.energy;
    totalEnergy += reward.energy;
    solved++;
    if (reward.firstTry) flawless++;
    if (reward.fast) fastSolves++;

    final newOrbs = <int>[];
    for (final orb in spec.orbs) {
      if (orbs.add(orb.kind)) newOrbs.add(orb.kind);
    }
    newOrbs.sort();

    (int, int)? decorEarned;
    if (reward.decor >= 0 && decor.add(r * 4 + reward.decor)) {
      decorEarned = (r, reward.decor);
    }

    final applied = Applied(
      reward: reward,
      spec: spec,
      newOrbs: newOrbs,
      decor: decorEarned,
      regionDone: reward.regionDone && regionComplete(r),
      firstClear: firstClear,
      bestStars: stars[r][l],
    );
    _save();
    return applied;
  }

  /// Pays for and opens a region. False when the core says it is not possible.
  Future<bool> openRegion(int r) async {
    if (regionOpen(r)) return true;
    final quote = NativeMath.instance.quote(
      r,
      previousDone: r == 0 ? levels : cleared(r - 1),
      energy: energy,
    );
    if (quote.status != UnlockStatus.payable && quote.status != UnlockStatus.free) {
      return false;
    }
    energy -= quote.cost;
    openRegions.add(r);
    await _save();
    return true;
  }

  UnlockQuote quote(int r) => NativeMath.instance.quote(
    r,
    previousDone: r == 0 ? levels : cleared(r - 1),
    energy: energy,
  );

  Future<void> reset() async {
    for (final row in stars) {
      row.fillRange(0, levels, 0);
    }
    energy = 0;
    totalEnergy = 0;
    solved = 0;
    flawless = 0;
    fastSolves = 0;
    tutorialBits = 0;
    orbs.clear();
    decor.clear();
    openRegions
      ..clear()
      ..add(0);
    await _save();
  }

  /// Test hook: opens everything up to a region with every level cleared.
  @visibleForTesting
  void debugClear(int regionsDone) {
    for (var r = 0; r < regions; r++) {
      for (var l = 0; l < levels; l++) {
        stars[r][l] = r < regionsDone ? 2 : 0;
      }
      if (r <= regionsDone) openRegions.add(r);
    }
    for (final o in orbDefs) {
      if (NativeMath.instance.orbDiscoveryIndex(o.id) < regionsDone * levels) {
        orbs.add(o.id);
      }
    }
    notifyListeners();
  }
}
