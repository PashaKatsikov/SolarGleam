import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let payload = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
      LaunchTap.capture(payload)
    }
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LaunchTap") {
      LaunchTap.attach(to: registrar.messenger())
    }
  }
}

/// The payload of the notification that cold-launched the app. Plugins register
/// only after the scene has connected, so FCM misses the launch response and
/// `getInitialMessage()` can resolve null; this is captured before the engine
/// exists instead. Held in memory only and handed to Dart exactly once.
enum LaunchTap {
  private static var payload: [String: Any]?
  private static var channel: FlutterMethodChannel?

  static func capture(_ userInfo: [AnyHashable: Any]) {
    payload = sanitize(userInfo)
  }

  static func attach(to messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "sg.l0", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "take" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let value = payload
      payload = nil
      result(value)
    }
    self.channel = channel
  }

  private static func sanitize(_ dict: [AnyHashable: Any]) -> [String: Any] {
    var out: [String: Any] = [:]
    for (key, value) in dict {
      guard let name = key as? String, let clean = sanitizeValue(value) else { continue }
      out[name] = clean
    }
    return out
  }

  private static func sanitizeValue(_ value: Any) -> Any? {
    switch value {
    case let string as String: return string
    case let number as NSNumber: return number
    case let dict as [AnyHashable: Any]: return sanitize(dict)
    case let array as [Any]: return array.compactMap(sanitizeValue)
    default: return nil
    }
  }
}
