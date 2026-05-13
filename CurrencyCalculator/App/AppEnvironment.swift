import Foundation

/// The composition root for the entire app.
///
/// `AppEnvironment` is the single place where every shared service is constructed
/// and owned for the lifetime of the scene. Coordinators receive an environment at
/// init time and pull out whatever dependencies they need — no service locators,
/// no singletons, no global state.
///
/// Adding a new dependency means:
///   1. Add a property here.
///   2. Build it in `live`.
///   3. Inject a mock in `AppEnvironment(config:exchangeService:)` for tests.
struct AppEnvironment {

    let config: AppConfiguration
    let exchangeService: ExchangeRateServiceProtocol

    // MARK: - Factories

    /// Production environment — reads config from the app bundle and builds
    /// the live network service. Computed once on first access (Swift static
    /// lets are lazy) so `AppConfiguration.load()` only runs once per process.
    static let live: AppEnvironment = {
        let config = AppConfiguration.load()
        return AppEnvironment(
            config: config,
            exchangeService: ExchangeRateService(config: config)
        )
    }()

    /// Test / preview environment — caller supplies all dependencies.
    /// Keeps `AppConfiguration.load()` (bundle I/O) out of unit tests entirely.
    static func testing(
        config: AppConfiguration,
        exchangeService: ExchangeRateServiceProtocol
    ) -> AppEnvironment {
        AppEnvironment(config: config, exchangeService: exchangeService)
    }
}
