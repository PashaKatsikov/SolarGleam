import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Packs an attribution payload into the edge-relay envelope.
///
/// Wire shape (field names + schema are unique per app — see the relay
/// deploy registry): `{ g: <rev>, j: <nonceHex>, c: <b64url>, u: <tag16> }`.
///
///   raw       = utf8(json(body))
///   keystream = sha256(secret + nonce + counterBE32) blocks
///   enc       = raw XOR keystream
///   payload   = base64url(enc) without padding
///   tag       = HMAC_sha256(secret, nonce + enc).hex()[:16]
class VeilPack {
  const VeilPack._();

  static const int _schemaRev = 17;
  static const String _fSchema = 'g';
  static const String _fNonce = 'j';
  static const String _fPayload = 'c';
  static const String _fTag = 'u';

  static final Random _rng = Random.secure();

  static Map<String, dynamic> seal(
    Map<String, dynamic> body, {
    required String secret,
  }) {
    final key = utf8.encode(secret);
    final raw = utf8.encode(jsonEncode(body));
    final nonce = Uint8List.fromList(
      List<int>.generate(16, (_) => _rng.nextInt(256)),
    );
    final stream = _keystream(key, nonce, raw.length);
    final enc = Uint8List(raw.length);
    for (var i = 0; i < raw.length; i++) {
      enc[i] = raw[i] ^ stream[i];
    }
    final tag = Hmac(
      sha256,
      key,
    ).convert(<int>[...nonce, ...enc]).toString().substring(0, 16);
    return <String, dynamic>{
      _fSchema: _schemaRev,
      _fNonce: _hex(nonce),
      _fPayload: base64Url.encode(enc).replaceAll('=', ''),
      _fTag: tag,
    };
  }

  static Uint8List _keystream(List<int> key, Uint8List nonce, int length) {
    final out = BytesBuilder();
    var counter = 0;
    while (out.length < length) {
      final block = <int>[
        ...key,
        ...nonce,
        (counter >> 24) & 0xff,
        (counter >> 16) & 0xff,
        (counter >> 8) & 0xff,
        counter & 0xff,
      ];
      out.add(sha256.convert(block).bytes);
      counter++;
    }
    return Uint8List.fromList(out.toBytes().sublist(0, length));
  }

  static String _hex(Uint8List bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }
}
