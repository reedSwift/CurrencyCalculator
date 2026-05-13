import Foundation
@testable import CurrencyCalculator

// @unchecked Sendable: mutable properties are only accessed from @MainActor
// test methods, so there is no actual data race.
final class MockExchangeRateService: ExchangeRateServiceProtocol, @unchecked Sendable {

    var currenciesResult: [String] = ["MXN", "ARS", "BRL", "COP"]
    /// Set to nil to simulate network failure with no valid cache (triggers .failed state).
    var ratesResult: RateResult? = RateResult(
        rates: ["MXN": 18.41, "ARS": 1545.0, "BRL": 5.70, "COP": 3832.0],
        source: .live,
        fetchedAt: Date()
    )

    func fetchAvailableCurrencies() async -> [String] {
        currenciesResult
    }

    func fetchRates(for currencies: [String]) async -> RateResult? {
        ratesResult
    }
}

// MARK: - Test configuration

extension AppConfiguration {
    static var test: AppConfiguration {
        AppConfiguration(
            apiBaseURL: "https://api.test.example.com/v1",
            tickersPath: "/tickers",
            currenciesPath: "/tickers-currencies",
            retryCount: 0,
            requestTimeout: 5,
            cacheMaxAgeHours: 24,
            fallbackCurrencies: [
                Currency(code: "MXN", flag: "🇲🇽"),
                Currency(code: "ARS", flag: "🇦🇷"),
                Currency(code: "BRL", flag: "🇧🇷"),
                Currency(code: "COP", flag: "🇨🇴"),
            ]
        )
    }
}
