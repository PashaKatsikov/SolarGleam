import '../core/native_strings.dart';

/// Runtime configuration. Identifiers, keys, endpoints, UA fragments, web
/// tweaks and on-screen copy are not kept as literals in the binary — they are
/// resolved from the native core on demand (see `rust/solar_math`).
///
/// The public pages below are the exception: they must match App Store Connect
/// verbatim, so they stay as plain constants.
abstract final class OrbitConfig {
  static const String privacyUrl = 'https://solar-gleam.com/privacy-policy';
  static const String supportUrl = 'https://solar-gleam.com/support';

  static String _s(CoreStr id) => NativeStrings.instance.read(id);

  static int _i(CoreStr id, int fallback) => int.tryParse(_s(id)) ?? fallback;

  static String get appTitle => _s(CoreStr.appTitle);
  static String get bundleId => _s(CoreStr.bundleId);
  static String get iosStoreId => _s(CoreStr.iosStoreId);
  static String get appleTeamId => _s(CoreStr.appleTeamId);

  static int get pushSnoozeSeconds => _i(CoreStr.pushSnoozeSeconds, 259189);
  static int get organicRecheckSeconds => _i(CoreStr.organicRecheckSeconds, 8);

  static String get endpoint => _s(CoreStr.endpoint);
  static String get gcdBase => _s(CoreStr.gcdBase);
  static String get signingSecret => _s(CoreStr.signingSecret);
  static String get appsFlyerKey => _s(CoreStr.appsFlyerKey);
  static String get firebaseProjectNumber => _s(CoreStr.firebaseProjectNumber);

  static String get uaProduct => _s(CoreStr.uaProduct);
  static String get uaPlatformPrefix => _s(CoreStr.uaPlatformPrefix);
  static String get uaPlatformSuffix => _s(CoreStr.uaPlatformSuffix);
  static String get uaEngine => _s(CoreStr.uaEngine);
  static String get uaMobileToken => _s(CoreStr.uaMobileToken);
  static String get safariVersion => _s(CoreStr.safariVersion);
  static String get safariTail => _s(CoreStr.safariTail);

  static String get notifyTitle => _s(CoreStr.notifyTitle);
  static String get notifySubtitle => _s(CoreStr.notifySubtitle);
  static String get notifyAccept => _s(CoreStr.notifyAccept);
  static String get notifySkip => _s(CoreStr.notifySkip);
  static String get nowifiTitle => _s(CoreStr.nowifiTitle);
  static String get nowifiSubtitle => _s(CoreStr.nowifiSubtitle);
  static String get retryLabel => _s(CoreStr.retry);
  static String get noConnectionYet => _s(CoreStr.noConnectionYet);

  static String get webInsetGuard => _s(CoreStr.webInsetGuard);
  static String get webZoomLock => _s(CoreStr.webZoomLock);
  static String get webTapPolish => _s(CoreStr.webTapPolish);
  static String get webKeyboardLift => _s(CoreStr.webKeyboardLift);
  static String get webFocusScale => _s(CoreStr.webFocusScale);
  static String get webInlineMedia => _s(CoreStr.webInlineMedia);

  static String get storeToken => 'id$iosStoreId';

  static bool get credentialsReady =>
      endpoint.isNotEmpty &&
      appsFlyerKey.isNotEmpty &&
      firebaseProjectNumber.isNotEmpty;
}
