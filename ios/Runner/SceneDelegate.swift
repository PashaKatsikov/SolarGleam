import Flutter
import UIKit

/// The cold-launch push destination is no longer captured or persisted here.
/// A tapped notification is resolved on the Dart side through FCM
/// (`FirebaseMessaging.getInitialMessage`) and loaded straight into the portal
/// web view, so the link is never written to disk.
class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }
}
