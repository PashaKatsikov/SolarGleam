import Flutter
import UIKit
import UserNotifications

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    // Must run before super: the engine (and its plugins) is created there.
    if let response = connectionOptions.notificationResponse {
      LaunchTap.capture(response.notification.request.content.userInfo)
    }
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }
}
