import UIKit

/// The root coordinator for the app.
///
/// Responsibilities:
///   - Set the window's `rootViewController` and call `makeKeyAndVisible()`.
///   - Decide which flow to start first (today: exchange; tomorrow could be
///     auth check → onboarding → exchange).
///   - Own child coordinators and manage their lifecycle.
///   - Handle deep links and push-notification routing by inspecting the
///     incoming `URLContexts` / `UNNotification` and delegating to the right
///     child coordinator.
///
/// What it does NOT do:
///   - Build views or know about UIKit layout.
///   - Contain business logic (that lives in ViewModels).
///   - Retain services directly (those come via AppEnvironment).
final class AppCoordinator: Coordinator {

    // MARK: - Properties

    private let window: UIWindow
    private let environment: AppEnvironment

    /// Retained child coordinators. Add a child before calling its start(),
    /// remove it when its flow is complete to release the sub-tree.
    private var childCoordinators: [Coordinator] = []

    /// Weak reference — the ViewModel is owned by MainViewController.
    /// Kept here so the coordinator can forward lifecycle events without
    /// the ViewModel needing to import UIKit or observe notifications itself.
    private weak var exchangeViewModel: ExchangeViewModel?

    // MARK: - Init

    init(window: UIWindow, environment: AppEnvironment) {
        self.window = window
        self.environment = environment
    }

    // MARK: - Coordinator

    func start() {
        // Future expansion point: check auth state, feature flags, onboarding
        // completion, etc. and route accordingly before showing the exchange screen.
        showExchangeFlow()
    }

    // MARK: - Deep link entry point
    //
    // SceneDelegate forwards universal links / custom-scheme URLs here.
    // The coordinator inspects the URL and either navigates in the current
    // flow or swaps to a different child coordinator.

    func handle(deepLink url: URL) {
        // Not implemented yet — placeholder to show the intended architecture.
        // Example: parse url.path, match "/exchange", call showExchangeFlow().
    }

    /// Called by SceneDelegate when the scene moves to the foreground.
    /// Triggers a silent rate refresh so the user always sees fresh data
    /// after returning to the app — without seeing a loading spinner.
    func handleForeground() {
        exchangeViewModel?.refreshIfNeeded()
    }

    // MARK: - Private flows

    private func showExchangeFlow() {
        let viewModel = ExchangeViewModel(
            service: environment.exchangeService,
            initialCurrencies: environment.config.fallbackCurrencies
        )
        exchangeViewModel = viewModel
        let rootVC = MainViewController(viewModel: viewModel)
        window.rootViewController = rootVC
        window.makeKeyAndVisible()
    }
}
