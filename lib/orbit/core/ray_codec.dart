import 'dart:convert';

/// Position-keyed XOR codec for at-rest string obfuscation.
///
/// This is deliberately a single-pass, position-keyed XOR against a
/// project-unique key — not a custom stream cipher with a key-schedule
/// loop. Only non-public values (config endpoint, relay secret, SDK keys,
/// UA fragments) are stored encoded; public URLs stay as plain constants.
const List<int> _rayKey = <int>[
  0x7A, 0x13, 0xC4, 0x56, 0x9E, 0x2B, 0xE1, 0x48,
  0x3F, 0xD5, 0x61, 0x8C, 0x07, 0xBA, 0x42, 0xF9,
  0x15, 0x6D, 0x93, 0x2E, 0xC8, 0x51, 0xAF, 0x3C,
];

int _mask(int index) => _rayKey[(index * 37 + 11) % _rayKey.length];

/// Decodes a byte array produced by `tool/encode_orbit_values.dart`.
String decodeRay(List<int> encoded) {
  if (encoded.isEmpty) return '';
  final out = List<int>.generate(
    encoded.length,
    (i) => (encoded[i] ^ _mask(i)) & 0xff,
  );
  return utf8.decode(out, allowMalformed: true);
}
