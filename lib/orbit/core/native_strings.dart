import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Keys for the runtime value table. Order must match the `i32` ids in
/// `rust/solar_math/src/strings.rs`.
enum CoreStr {
  endpoint,
  gcdBase,
  signingSecret,
  appsFlyerKey,
  firebaseProjectNumber,
  uaProduct,
  uaPlatformPrefix,
  uaPlatformSuffix,
  uaEngine,
  uaMobileToken,
  safariVersion,
  safariTail,
  notifyTitle,
  notifySubtitle,
  notifyAccept,
  notifySkip,
  nowifiTitle,
  nowifiSubtitle,
  retry,
  noConnectionYet,
  webInsetGuard,
  webZoomLock,
  webTapPolish,
  webKeyboardLift,
  webFocusScale,
  webInlineMedia,
  appTitle,
  bundleId,
  iosStoreId,
  appleTeamId,
  pushSnoozeSeconds,
  organicRecheckSeconds,
}

/// Reads values out of the native core (`sg_s5`). Each value is pulled across
/// the FFI boundary once and cached.
class NativeStrings {
  NativeStrings._(this._read);

  final int Function(int id, Pointer<Uint8> out, int cap) _read;
  final Map<int, String> _cache = <int, String>{};

  static final NativeStrings instance = _load();

  static NativeStrings _load() {
    final read = _open()
        .lookupFunction<
          Int32 Function(Int32, Pointer<Uint8>, Int32),
          int Function(int, Pointer<Uint8>, int)
        >('sg_s5');
    return NativeStrings._(read);
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

  String read(CoreStr id) {
    final key = id.index;
    final cached = _cache[key];
    if (cached != null) return cached;
    final needed = _read(key, nullptr, 0);
    if (needed <= 0) return _cache[key] = '';
    final buffer = calloc<Uint8>(needed);
    try {
      final written = _read(key, buffer, needed);
      if (written <= 0) return _cache[key] = '';
      final value = utf8.decode(buffer.asTypedList(written));
      return _cache[key] = value;
    } finally {
      calloc.free(buffer);
    }
  }
}
