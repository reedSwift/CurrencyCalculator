import Foundation

// MARK: - Rate result types

enum RateSource {
    case live
    case cached
}

struct RateResult {
    let rates: [String: Double]
    let source: RateSource
    let fetchedAt: Date
}

// MARK: - Protocol

protocol ExchangeRateServiceProtocol {
    func fetchAvailableCurrencies() async -> [String]
    /// Returns nil when no valid data is available — network failed AND no
    /// cache exists or the cache is older than the configured max age.
    func fetchRates(for currencies: [String]) async -> RateResult?
}

// MARK: - Cached rates model

/// Persisted to the Caches directory. iOS may evict this under storage pressure,
/// which is correct behaviour — it is recoverable data, not user data.
private struct CachedRates: Codable {
    let rates: [String: Double]
    let fetchedAt: Date
}

// MARK: - Live implementation

final class ExchangeRateService: ExchangeRateServiceProtocol {

    private let config: AppConfiguration
    private let session: URLSession
    private let ratesCacheFileURL: URL
    private let currenciesCacheFileURL: URL

    /// Production init — both caches land in the system Caches directory.
    init(config: AppConfiguration, session: URLSession = .shared) {
        self.config = config
        self.session = session
        self.ratesCacheFileURL = Self.defaultRatesCacheFileURL
        self.currenciesCacheFileURL = Self.defaultCurrenciesCacheFileURL
    }

    /// Testable init — caller supplies temp-directory URLs so tests stay isolated.
    init(config: AppConfiguration, session: URLSession = .shared,
         ratesCacheFileURL: URL, currenciesCacheFileURL: URL) {
        self.config = config
        self.session = session
        self.ratesCacheFileURL = ratesCacheFileURL
        self.currenciesCacheFileURL = currenciesCacheFileURL
    }

    // MARK: - Default cache locations

    private static var defaultRatesCacheFileURL: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("com.currencycalculator.exchange_rates.json")
    }

    private static var defaultCurrenciesCacheFileURL: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("com.currencycalculator.currencies.json")
    }

    // MARK: - Network (public protocol)

    func fetchAvailableCurrencies() async -> [String] {
        guard let url = URL(string: config.currenciesURL) else {
            return cachedOrBundledCurrencies()
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = config.requestTimeout

        do {
            let (data, _) = try await session.data(for: request)
            let codes = try JSONDecoder().decode([String].self, from: data)
            persistCurrencies(codes)
            return codes
        } catch {
            return cachedOrBundledCurrencies()
        }
    }

    func fetchRates(for currencies: [String]) async -> RateResult? {
        do {
            let newRates = try await fetchRatesFromNetwork(for: currencies)
            let now = Date()
            persist(CachedRates(rates: newRates, fetchedAt: now))
            return RateResult(rates: newRates, source: .live, fetchedAt: now)
        } catch {
            return validCachedResult()
        }
    }

    // MARK: - Network (private)

    private func fetchRatesFromNetwork(for currencies: [String]) async throws -> [String: Double] {
        let query = currencies.joined(separator: ",")
        guard let url = URL(string: "\(config.tickersURL)?currencies=\(query)") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = config.requestTimeout

        var lastError: Error = URLError(.unknown)
        for attempt in 0...config.retryCount {
            do {
                let (data, _) = try await session.data(for: request)
                let tickers = try JSONDecoder().decode([Ticker].self, from: data)
                return tickers.reduce(into: [:]) { dict, ticker in
                    if let code = ticker.currencyCode, let rate = ticker.midRate {
                        dict[code] = rate
                    }
                }
            } catch {
                lastError = error
                if attempt < config.retryCount {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
            }
        }
        throw lastError
    }

    // MARK: - Rates file cache

    private func persist(_ cached: CachedRates) {
        guard let data = try? JSONEncoder().encode(cached) else { return }
        try? data.write(to: ratesCacheFileURL, options: .atomic)
    }

    private func loadCachedRates() -> CachedRates? {
        guard
            let data = try? Data(contentsOf: ratesCacheFileURL),
            let cached = try? JSONDecoder().decode(CachedRates.self, from: data),
            !cached.rates.isEmpty
        else { return nil }
        return cached
    }

    /// Returns a `RateResult` only if a cache file exists and is within `config.cacheMaxAge`.
    /// Returns nil when no cache exists or the cache is too old to trust.
    private func validCachedResult() -> RateResult? {
        guard let cached = loadCachedRates() else { return nil }
        let age = Date().timeIntervalSince(cached.fetchedAt)
        guard age <= config.cacheMaxAge else { return nil }
        return RateResult(rates: cached.rates, source: .cached, fetchedAt: cached.fetchedAt)
    }

    // MARK: - Currencies file cache

    private func persistCurrencies(_ codes: [String]) {
        guard let data = try? JSONEncoder().encode(codes) else { return }
        try? data.write(to: currenciesCacheFileURL, options: .atomic)
    }

    private func loadCachedCurrencies() -> [String]? {
        guard
            let data = try? Data(contentsOf: currenciesCacheFileURL),
            let codes = try? JSONDecoder().decode([String].self, from: data),
            !codes.isEmpty
        else { return nil }
        return codes
    }

    /// File cache → bundle → empty.
    /// No staleness check: an old currency list is never dangerously wrong,
    /// it just might be missing a newly added currency until connectivity returns.
    private func cachedOrBundledCurrencies() -> [String] {
        if let cached = loadCachedCurrencies() { return cached }
        return bundledCurrencies()
    }

    // MARK: - Bundle fallback (currencies only — absolute last resort)

    private func bundledCurrencies() -> [String] {
        guard
            let url = Bundle.main.url(forResource: "currencies", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let codes = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return codes
    }
}
