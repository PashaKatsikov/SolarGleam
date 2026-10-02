// ignore_for_file: avoid_print

import 'dart:convert';

/// Keep this key byte-for-byte in sync with `_rayKey` in
/// lib/orbit/core/ray_codec.dart. Change it (and re-run) to re-diversify.
const List<int> _rayKey = <int>[
  0x7A, 0x13, 0xC4, 0x56, 0x9E, 0x2B, 0xE1, 0x48,
  0x3F, 0xD5, 0x61, 0x8C, 0x07, 0xBA, 0x42, 0xF9,
  0x15, 0x6D, 0x93, 0x2E, 0xC8, 0x51, 0xAF, 0x3C,
];

int _mask(int index) => _rayKey[(index * 37 + 11) % _rayKey.length];

List<int> fold(String value) {
  final bytes = utf8.encode(value);
  return List<int>.generate(bytes.length, (i) => (bytes[i] ^ _mask(i)) & 0xff);
}

String unfold(List<int> encoded) {
  final out = List<int>.generate(
    encoded.length,
    (i) => (encoded[i] ^ _mask(i)) & 0xff,
  );
  return utf8.decode(out, allowMalformed: true);
}

void main() {
  // Public URLs (privacy/support) are NOT encoded — they live as plain
  // constants in orbit_config.dart and match App Store Connect.
  const values = <String, String>{
    'endpoint': 'https://solar-gleam.com/edge/sync',
    'gcd': 'https://gcdsdk.appsflyer.com/install_data/v5.0/',
    'relaySecret': 'uYuNdyh-JCgwo4ZQTfBP7nglUpvpxwC3wtNVjliGKNg',
    'uaProduct': 'Mozilla/5.0',
    'uaPlatformPrefix': '(iPhone; CPU iPhone OS',
    'uaPlatformSuffix': 'like Mac OS X)',
    'uaEngine': 'AppleWebKit/605.1.15 (KHTML, like Gecko)',
    'uaMobileToken': 'Mobile/15E148',
    'safari': '18.5',
    'safariTail': '604.1',
    'appsFlyerDevKey': 'fC23ZwDv7CixWHzkSboGB7',
    'firebaseProjectNumber': '550276010584',
  };

  for (final entry in values.entries) {
    final encoded = fold(entry.value);
    print('${entry.key}: <int>[${encoded.join(', ')}]');
    if (unfold(encoded) != entry.value) {
      throw StateError('Round-trip failed for ${entry.key}');
    }
  }
  print('VERIFY: all values round-tripped');
}
