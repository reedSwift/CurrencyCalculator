import Foundation

struct AppConfiguration {
    let apiBaseURL: String
    let tickersPath: String
    let currenciesPath: String
    let retryCount: Int
    let requestTimeout: TimeInterval
    let cacheMaxAgeHours: Int
    let fallbackCurrencies: [Currency]  // initial value before network responds

    var tickersURL: String { apiBaseURL + tickersPath }
    var currenciesURL: String { apiBaseURL + currenciesPath }
    /// How long a cached rate file is considered valid before it is treated as stale.
    var cacheMaxAge: TimeInterval { TimeInterval(cacheMaxAgeHours) * 3_600 }
}

// MARK: - Loading

extension AppConfiguration {

    static func load() -> AppConfiguration {
        let configFileName: String
        #if DEBUG
        configFileName = "config.debug"
        #else
        configFileName = "config.release"
        #endif
        return load(configFileName: configFileName)
    }

    // Internal so tests can call with a specific filename if needed
    static func load(configFileName: String) -> AppConfiguration {
        let dto = loadDTO(named: configFileName)
        return AppConfiguration(
            apiBaseURL: dto.apiBaseURL,
            tickersPath: dto.endpoints.tickers,
            currenciesPath: dto.endpoints.currencies,
            retryCount: dto.retryCount,
            requestTimeout: dto.requestTimeout,
            cacheMaxAgeHours: dto.cacheMaxAgeHours,
            fallbackCurrencies: loadCurrencies()
        )
    }

    private static func loadDTO(named name: String) -> ConfigDTO {
        guard
            let url = Bundle.main.url(forResource: name, withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let dto = try? JSONDecoder().decode(ConfigDTO.self, from: data)
        else {
            // Belt-and-suspenders: should never happen in a correctly set-up build
            fatalError("Missing or malformed \(name).json in bundle")
        }
        return dto
    }

    private static func loadCurrencies() -> [Currency] {
        guard
            let url = Bundle.main.url(forResource: "currencies", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let codes = try? JSONDecoder().decode([String].self, from: data)
        else {
            return []
        }
        return codes.map { Currency.make(code: $0) }
    }
}

// MARK: - Private DTOs

private struct ConfigDTO: Decodable {
    let apiBaseURL: String
    let endpoints: EndpointsDTO
    let retryCount: Int
    let requestTimeout: TimeInterval
    let cacheMaxAgeHours: Int

    struct EndpointsDTO: Decodable {
        let tickers: String
        let currencies: String
    }
}

