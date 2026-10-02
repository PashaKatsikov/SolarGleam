import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Thin bridge to the Rust math core (rust/solar_math). On iOS the core is
/// linked into the app, so symbols come from the process itself.
class NativeMath {
  NativeMath._(DynamicLibrary lib)
    : _init = lib.lookupFunction<Int32 Function(), int Function()>('sg_k0'),
      _spin = lib
          .lookupFunction<
            Int32 Function(Pointer<Uint8>, Int32),
            int Function(Pointer<Uint8>, int)
          >('sg_g1'),
      _eval = lib
          .lookupFunction<
            Int32 Function(
              Pointer<Uint8>,
              Int32,
              Int64,
              Int32,
              Pointer<Int64>,
              Int32,
            ),
            int Function(Pointer<Uint8>, int, int, int, Pointer<Int64>, int)
          >('sg_e2'),
      _pay = lib
          .lookupFunction<
            Int64 Function(Int32, Int32, Int64),
            int Function(int, int, int)
          >('sg_p3'),
      _constant = lib.lookupFunction<Int64 Function(Int32), int Function(int)>(
        'sg_c4',
      );

  static const gridCells = 16;
  static const resultCapacity = 128;

  static final NativeMath instance = _load();

  static NativeMath _load() {
    final math = NativeMath._(_open());
    if (math._init() != 1) {
      throw StateError('The math core failed its integrity check.');
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
      'Math core not found. Run `cargo build --release` in rust/solar_math '
      'or set SOLAR_MATH_LIB.',
    );
  }

  final int Function() _init;
  final int Function(Pointer<Uint8>, int) _spin;
  final int Function(Pointer<Uint8>, int, int, int, Pointer<Int64>, int) _eval;
  final int Function(int, int, int) _pay;
  final int Function(int) _constant;

  final Pointer<Uint8> _gridBuffer = calloc<Uint8>(gridCells);
  final Pointer<Int64> _resultBuffer = calloc<Int64>(resultCapacity);

  /// Random grid as symbol indices, reel-major.
  List<int> spin() {
    final written = _spin(_gridBuffer, gridCells);
    if (written != gridCells) {
      throw StateError('The math core could not spin.');
    }
    return [for (var i = 0; i < gridCells; i++) _gridBuffer[i]];
  }

  /// Raw result words. See `sg_e2` in rust/solar_math/src/lib.rs.
  List<int> evaluate(List<int> grid, int totalBet, bool freeSpin) {
    if (grid.length != gridCells) {
      throw ArgumentError.value(grid.length, 'grid', 'expected $gridCells');
    }
    for (var i = 0; i < gridCells; i++) {
      _gridBuffer[i] = grid[i];
    }
    final words = _eval(
      _gridBuffer,
      gridCells,
      totalBet,
      freeSpin ? 1 : 0,
      _resultBuffer,
      resultCapacity,
    );
    if (words <= 0) {
      throw StateError('The math core rejected the grid.');
    }
    return [for (var i = 0; i < words; i++) _resultBuffer[i]];
  }

  int linePay(int symbol, int count, int lineBet) =>
      _pay(symbol, count, lineBet);

  int constant(int id) => _constant(id);
}
