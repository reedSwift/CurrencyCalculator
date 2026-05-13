import UIKit

/// Owns the UIWindow and the root coordinator for this scene.
///
/// SceneDelegate has exactly one job: wire the window to the coordinator and
/// forward scene lifecycle events (foreground/background/deep links) to it.
/// All routing decisions live in AppCoordinator, not here.
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var appCoordinator: AppCoordinator?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        self.window = window

        appCoordinator = AppCoordinator(window: window, environment: .live)
        appCoordinator?.start()
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        appCoordinator?.handleForeground()
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        appCoordinator?.handle(deepLink: url)
    }
}
