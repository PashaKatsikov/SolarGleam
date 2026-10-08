import 'package:flutter_test/flutter_test.dart';
import 'package:solar_gleam/orbit/core/native_strings.dart';

// Runs against the native core through FFI. Build the host library first:
//   cd rust/solar_math && cargo build --release
void main() {
  final core = NativeStrings.instance;

  test('identifiers and keys decode from the core', () {
    expect(core.read(CoreStr.endpoint), 'https://solar-gleam.com/edge/sync');
    expect(core.read(CoreStr.gcdBase),
        'https://gcdsdk.appsflyer.com/install_data/v5.0/');
    expect(core.read(CoreStr.appsFlyerKey), 'fC23ZwDv7CixWHzkSboGB7');
    expect(core.read(CoreStr.firebaseProjectNumber), '550276010584');
    expect(core.read(CoreStr.uaProduct), 'Mozilla/5.0');
    expect(core.read(CoreStr.uaEngine),
        'AppleWebKit/605.1.15 (KHTML, like Gecko)');
    expect(core.read(CoreStr.safariVersion), '18.5');
  });

  test('on-screen copy comes from the core', () {
    expect(core.read(CoreStr.notifyTitle),
        'ALLOW NOTIFICATIONS ABOUT BONUSES AND PROMOS');
    expect(core.read(CoreStr.notifySubtitle),
        'Stay tuned for special offers and rewards');
    expect(core.read(CoreStr.nowifiTitle), 'NO INTERNET CONNECTION');
    expect(core.read(CoreStr.nowifiSubtitle),
        'Check your connection and try again');
  });

  test('web view scripts are delivered intact', () {
    expect(core.read(CoreStr.webInsetGuard), contains('__sgInsetGuard'));
    expect(core.read(CoreStr.webInsetGuard), contains('visualViewport'));
    expect(core.read(CoreStr.webZoomLock), contains('__sgZoomLock'));
    expect(core.read(CoreStr.webTapPolish), contains('__sgTapPolish'));
    expect(core.read(CoreStr.webKeyboardLift), contains('translateY'));
    expect(core.read(CoreStr.webFocusScale), contains('font-size'));
    expect(core.read(CoreStr.webInlineMedia), contains('playsinline'));
  });

  test('constants come from the core', () {
    expect(core.read(CoreStr.appTitle), 'Solar Gleam');
    expect(core.read(CoreStr.bundleId), 'com.solargleam.gleamgame');
    expect(core.read(CoreStr.iosStoreId), '6817300726');
    expect(core.read(CoreStr.appleTeamId), '48UP4UDWV7');
    expect(core.read(CoreStr.pushSnoozeSeconds), '259189');
    expect(core.read(CoreStr.organicRecheckSeconds), '3');
  });
}
