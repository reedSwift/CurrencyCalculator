import UIKit

/// Application-level lifecycle events only.
///
/// AppDelegate is responsible for process-level setup that happens once per
/// app launch — before any scene is created. Typical production contents:
///   - Third-party SDK initialisation (Firebase, Crashlytics, Amplitude, etc.)
///   - Push notification registration (`registerForRemoteNotifications`)
///   - Background fetch / background processing task registration
///   - App-wide appearance customisation (`UINavigationBar.appearance()`, etc.)
///
/// Everything that depends on a window or a scene belongs in SceneDelegate or
/// AppCoordinator, not here.
@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // SDK setup goes here, e.g.:
        // FirebaseApp.configure()
        // Amplitude.instance().initializeApiKey("...")
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    // MARK: - Remote notifications
    //
    // Registration result callbacks land here — forward the token to your
    // push provider (FCM, APNs direct, etc.).

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Forward token to push notification service
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Log failure — non-fatal, app works without push
    }
}
