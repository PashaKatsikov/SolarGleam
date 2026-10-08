import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// One orb on the board as the core describes it.
class OrbSpec {
  const OrbSpec({required this.kind, required this.glyph, required this.slot});

  /// Orb id in discovery order (0 = Azure ... 11 = Void).
  final int kind;
  final int glyph;

  /// Starting slot on the ring.
  final int slot;
}

enum PreviewKind { real, ghost, glyph }

/// One beat of the preview.
class PreviewEvent {
  const PreviewEvent(this.kind, this.value);

  final PreviewKind kind;

  /// Orb index for real and ghost flashes, glyph id for glyph tokens.
  final int value;
}

class PuzzleSpec {
  const PuzzleSpec({
    required this.region,
    required this.level,
    required this.modes,
    required this.attempts,
    required this.hints,
    required this.replays,
    required this.flashMs,
    required this.gapMs,
    required this.sequenceLength,
    required this.orbs,
    required this.events,
    required this.shiftTo,
  });

  final int region;
  final int level;
  final int modes;
  final int attempts;
  final int hints;
  final int replays;
  final int flashMs;
  final int gapMs;
  final int sequenceLength;
  final List<OrbSpec> orbs;
  final List<PreviewEvent> events;

  /// Slot each orb moves to when the shift rule is active.
  final List<int> shiftTo;

  bool get shifts => modes & 16 != 0;
}

enum TapOutcome { ignored, right, wrong, lost, solved }

class TapResult {
  const TapResult(this.outcome, this.entered, this.attemptsLeft, this.length);

  final TapOutcome outcome;
  final int entered;
  final int attemptsLeft;
  final int length;
}

class RewardSpec {
  const RewardSpec({
    required this.stars,
    required this.energy,
    required this.fast,
    required this.firstTry,
    required this.decor,
    required this.regionDone,
    required this.mistakes,
    required this.aids,
  });

  final int stars;
  final int energy;
  final bool fast;
  final bool firstTry;

  /// Decor index (0-3) handed out by this level, or -1.
  final int decor;
  final bool regionDone;
  final int mistakes;
  final int aids;
}

enum UnlockStatus { free, payable, locked, short }

class UnlockQuote {
  const UnlockQuote(this.status, this.cost);

  final UnlockStatus status;
  final int cost;
}

/// Bridge to the Rust puzzle core (rust/solar_math). On iOS the core is linked
/// into the app, so symbols come from the process itself.
class NativeMath {
  NativeMath._(DynamicLibrary lib)
    : _init = lib.lookupFunction<Int32 Function(), int Function()>('sg_k0'),
      _start = lib
          .lookupFunction<
            Int32 Function(Int32, Int32, Pointer<Int32>, Int32),
            int Function(int, int, Pointer<Int32>, int)
          >('sg_n1'),
      _tap = lib.lookupFunction<Int32 Function(Int32), int Function(int)>('sg_t2'),
      _aid = lib.lookupFunction<Int32 Function(Int32), int Function(int)>('sg_h3'),
      _finish = lib
          .lookupFunction<
            Int32 Function(Int32, Int32, Pointer<Int32>, Int32),
            int Function(int, int, Pointer<Int32>, int)
          >('sg_f5'),
      _unlock = lib
          .lookupFunction<
            Int32 Function(Int32, Int32, Int32),
            int Function(int, int, int)
          >('sg_u7'),
      _constant = lib
          .lookupFunction<Int32 Function(Int32, Int32), int Function(int, int)>(
            'sg_c4',
          ),
      _probe = lib.providesSymbol('sg_d9')
          ? lib.lookupFunction<Int32 Function(), int Function()>('sg_d9')
          : null;

  static const _capacity = 256;
  static const _rewardWords = 8;

  static final NativeMath instance = _load();

  static NativeMath _load() {
    final math = NativeMath._(_open());
    if (math._init() != 1) {
      throw StateError('The puzzle core failed its integrity check.');
    }
    return math;
  }

  static DynamicLibrary _open() {
    if (Platform.isIOS) return DynamicLibrary.process();
    // Host runs (flutter test): build with `cargo build --release` first.
    final candidates = <String>[
      ?Platform.environment['SOLAR_MATH_LIB'],
      'rust/solar_math/target/release/libsolar_math.dylib',
      'rust/solar_math/target/release/libsolar_math.so',
    ];
    for (final path in candidates) {
      if (File(path).existsSync()) return DynamicLibrary.open(path);
    }
    throw StateError(
      'Puzzle core not found. Run `cargo build --release` in rust/solar_math '
      'or set SOLAR_MATH_LIB.',
    );
  }

  final int Function() _init;
  final int Function(int, int, Pointer<Int32>, int) _start;
  final int Function(int) _tap;
  final int Function(int) _aid;
  final int Function(int, int, Pointer<Int32>, int) _finish;
  final int Function(int, int, int) _unlock;
  final int Function(int, int) _constant;
  final int Function()? _probe;

  final Pointer<Int32> _buffer = calloc<Int32>(_capacity);

  /// True when the core was built for test automation.
  bool get hasProbe => _probe != null;

  /// The orb index the running puzzle expects next. Test builds only.
  int probeNext() => _probe?.call() ?? -1;

  PuzzleSpec? start(int region, int level) {
    final written = _start(region, level, _buffer, _capacity);
    if (written <= 0) return null;
    final w = _buffer.asTypedList(written);
    final n = w[0];
    final eventCount = w[8];
    var at = 10;
    final orbs = <OrbSpec>[];
    for (var i = 0; i < n; i++) {
      orbs.add(OrbSpec(kind: w[at], glyph: w[at + 1], slot: w[at + 2]));
      at += 3;
    }
    final events = <PreviewEvent>[];
    for (var i = 0; i < eventCount; i++) {
      events.add(PreviewEvent(PreviewKind.values[w[at]], w[at + 1]));
      at += 2;
    }
    final shiftTo = [for (var i = 0; i < n; i++) w[at + i]];
    return PuzzleSpec(
      region: region,
      level: level,
      modes: w[1],
      attempts: w[2],
      hints: w[3],
      replays: w[4],
      flashMs: w[5],
      gapMs: w[6],
      sequenceLength: w[7],
      orbs: orbs,
      events: events,
      shiftTo: shiftTo,
    );
  }

  TapResult tap(int orb) {
    final packed = _tap(orb);
    final outcome = switch (packed & 0xFF) {
      1 => TapOutcome.right,
      2 => TapOutcome.wrong,
      3 => TapOutcome.lost,
      4 => TapOutcome.solved,
      _ => TapOutcome.ignored,
    };
    return TapResult(
      outcome,
      (packed >> 8) & 0xFF,
      (packed >> 16) & 0xFF,
      (packed >> 24) & 0x7F,
    );
  }

  /// Spends a replay. True when one was available.
  bool replay() => _aid(0) == 1;

  /// Spends a hint. Returns the orb index to point at, or -1.
  int hint() => _aid(1);

  RewardSpec? finish({required int elapsedMs, required bool repeat}) {
    final written = _finish(elapsedMs, repeat ? 1 : 0, _buffer, _rewardWords);
    if (written != _rewardWords) return null;
    final w = _buffer.asTypedList(_rewardWords);
    return RewardSpec(
      stars: w[0],
      energy: w[1],
      fast: w[2] == 1,
      firstTry: w[3] == 1,
      decor: w[4],
      regionDone: w[5] == 1,
      mistakes: w[6],
      aids: w[7],
    );
  }

  UnlockQuote quote(int region, {required int previousDone, required int energy}) {
    final result = _unlock(region, previousDone, energy);
    if (result == -1) return const UnlockQuote(UnlockStatus.locked, 0);
    if (result == -2) {
      return UnlockQuote(UnlockStatus.short, regionCost(region));
    }
    return UnlockQuote(result == 0 ? UnlockStatus.free : UnlockStatus.payable, result);
  }

  int get regionCount => _constant(0, 0);
  int get levelCount => _constant(1, 0);
  int get orbCount => _constant(2, 0);
  int regionCost(int region) => _constant(3, region);

  /// Global level index (region * 8 + level) at which an orb joins the game.
  int orbDiscoveryIndex(int orb) => _constant(4, orb);

  int modesOf(int region, int level) => _constant(5, region * levelCount + level);
  int orbsOf(int region, int level) => _constant(6, region * levelCount + level);
  int lengthOf(int region, int level) => _constant(7, region * levelCount + level);
  int baseEnergyOf(int region, int level) => _constant(8, region * levelCount + level);
  int attemptsOf(int region) => _constant(9, region);
}
