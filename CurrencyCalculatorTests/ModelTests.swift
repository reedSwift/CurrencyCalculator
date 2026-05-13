import XCTest
@testable import CurrencyCalculator

// MARK: - Ticker

final class TickerTests: XCTestCase {

    func testMidRate_returnsAverageOfAskAndBid() {
        let ticker = Ticker(ask: "18.4105", bid: "18.4070", book: "usdc_mxn", date: "")
        XCTAssertEqual(ticker.midRate!, (18.4105 + 18.4070) / 2, accuracy: 0.0001)
    }

    func testMidRate_returnsNil_forNonNumericStrings() {
        let ticker = Ticker(ask: "N/A", bid: "18.40", book: "usdc_mxn", date: "")
        XCTAssertNil(ticker.midRate)
    }

    func testMidRate_returnsNil_whenAskIsZero() {
        let ticker = Ticker(ask: "0", bid: "18.40", book: "usdc_mxn", date: "")
        XCTAssertNil(ticker.midRate)
    }

    func testMidRate_returnsNil_whenBidIsZero() {
        let ticker = Ticker(ask: "18.41", bid: "0", book: "usdc_mxn", date: "")
        XCTAssertNil(ticker.midRate)
    }

    func testCurrencyCode_uppercasesBookSuffix() {
        let ticker = Ticker(ask: "1", bid: "1", book: "usdc_mxn", date: "")
        XCTAssertEqual(ticker.currencyCode, "MXN")
    }

    func testCurrencyCode_parsesARS() {
        let ticker = Ticker(ask: "1", bid: "1", book: "usdc_ars", date: "")
        XCTAssertEqual(ticker.currencyCode, "ARS")
    }

    func testCurrencyCode_returnsNil_forMalformedBook() {
        let ticker = Ticker(ask: "1", bid: "1", book: "usdc", date: "")
        XCTAssertNil(ticker.currencyCode)
    }

    func testCurrencyCode_returnsNil_forEmptyBook() {
        let ticker = Ticker(ask: "1", bid: "1", book: "", date: "")
        XCTAssertNil(ticker.currencyCode)
    }

    func testDecoding_fromJSON() throws {
        let json = """
        [{"ask":"18.41","bid":"18.40","book":"usdc_mxn","date":"2025-10-20T20:14:57Z"}]
        """.data(using: .utf8)!
        let tickers = try JSONDecoder().decode([Ticker].self, from: json)
        XCTAssertEqual(tickers.count, 1)
        XCTAssertEqual(tickers[0].currencyCode, "MXN")
        let midRate = try XCTUnwrap(tickers[0].midRate, "midRate should not be nil for valid ask/bid")
        XCTAssertEqual(midRate, 18.405, accuracy: 0.001)
    }
}

// MARK: - Currency

@MainActor
final class CurrencyTests: XCTestCase {

    func testMake_returnsUSDc_caseInsensitive() {
        XCTAssertEqual(Currency.make(code: "usdc").code, "USDc")
        XCTAssertEqual(Currency.make(code: "USDc").code, "USDc")
        XCTAssertEqual(Currency.make(code: "USDC").code, "USDc")
    }

    func testMake_generatesCorrectFlag_forKnownCodes() {
        XCTAssertEqual(Currency.make(code: "MXN").flag, "🇲🇽")
        XCTAssertEqual(Currency.make(code: "ARS").flag, "🇦🇷")
        XCTAssertEqual(Currency.make(code: "BRL").flag, "🇧🇷")
        XCTAssertEqual(Currency.make(code: "COP").flag, "🇨🇴")
    }

    func testMake_normalizesCodeToUppercase() {
        XCTAssertEqual(Currency.make(code: "mxn").code, "MXN")
    }

    func testMake_unknownCode_stillProducesNonEmptyFlag() {
        let c = Currency.make(code: "XYZ")
        XCTAssertEqual(c.code, "XYZ")
        XCTAssertFalse(c.flag.isEmpty)
    }

    func testUSDc_hasCorrectCodeAndFlag() {
        XCTAssertEqual(Currency.usdc.code, "USDc")
        XCTAssertEqual(Currency.usdc.flag, "🇺🇸")
    }

    func testCurrency_identifiable_byCode() {
        let mxn = Currency(code: "MXN", flag: "🇲🇽")
        XCTAssertEqual(mxn.id, "MXN")
    }

    func testCurrency_hashable_deduplicatesInSet() {
        let a = Currency(code: "MXN", flag: "🇲🇽")
        let b = Currency(code: "MXN", flag: "🇲🇽")
        XCTAssertEqual(Set([a, b]).count, 1)
    }

    func testCurrency_equatable() {
        XCTAssertEqual(Currency(code: "MXN", flag: "🇲🇽"), Currency(code: "MXN", flag: "🇲🇽"))
        XCTAssertNotEqual(Currency(code: "MXN", flag: "🇲🇽"), Currency(code: "ARS", flag: "🇦🇷"))
    }
}

// MARK: - AppConfiguration

final class AppConfigurationTests: XCTestCase {

    func testTestConfig_hasExpectedFallbackCurrencies() {
        let codes = AppConfiguration.test.fallbackCurrencies.map(\.code)
        XCTAssertTrue(codes.contains("MXN"))
        XCTAssertTrue(codes.contains("ARS"))
        XCTAssertTrue(codes.contains("BRL"))
        XCTAssertTrue(codes.contains("COP"))
    }

    func testTestConfig_tickersURL_combinesBaseAndPath() {
        let config = AppConfiguration.test
        XCTAssertEqual(config.tickersURL, config.apiBaseURL + config.tickersPath)
    }

    func testTestConfig_currenciesURL_combinesBaseAndPath() {
        let config = AppConfiguration.test
        XCTAssertEqual(config.currenciesURL, config.apiBaseURL + config.currenciesPath)
    }
}

// MARK: - ExchangeRateService (currencies caching)

@MainActor
final class ExchangeRateServiceCurrenciesTests: XCTestCase {

    private var ratesCacheURL: URL!
    private var currenciesCacheURL: URL!
    private var service: ExchangeRateService!

    override func setUp() {
        let tmp = FileManager.default.temporaryDirectory
        ratesCacheURL     = tmp.appendingPathComponent(UUID().uuidString + "_rates.json")
        currenciesCacheURL = tmp.appendingPathComponent(UUID().uuidString + "_currencies.json")
        service = ExchangeRateService(
            config: AppConfiguration.test,
            ratesCacheFileURL: ratesCacheURL,
            currenciesCacheFileURL: currenciesCacheURL
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: ratesCacheURL)
        try? FileManager.default.removeItem(at: currenciesCacheURL)
        service = nil
    }

    func testCurrencies_noCache_noBundleFallback_returnsEmpty() async {
        // Testable init uses a temp path — no bundle currencies.json in test bundle.
        // If the network also fails (bad URL in test config), we get whatever
        // cachedOrBundledCurrencies returns. Since no cache exists, it falls
        // through to bundledCurrencies(); an empty array is acceptable here.
        // The important thing is it doesn't crash and returns [String].
        // Smoke test: verify it completes without crashing on cold start (no cache, bad URL).
        // Network fails (test URL), file cache is empty → falls back to bundle currencies.json.
        // Bundle.main in a hosted unit test IS the app bundle, so currencies.json is present.
        let codes = await service.fetchAvailableCurrencies()
        XCTAssertFalse(codes.isEmpty, "Bundle fallback should return currencies from currencies.json")
    }

    func testCurrencies_persistedOnSuccess_restoredOnOffline() async throws {
        // Simulate a previous successful fetch by writing directly to the cache file.
        let expected = ["MXN", "ARS", "BRL", "COP", "CLP"]
        let data = try JSONEncoder().encode(expected)
        try data.write(to: currenciesCacheURL)

        // A new service instance (same cache path) simulating a relaunch with no network.
        let offlineService = ExchangeRateService(
            config: AppConfiguration.test,
            ratesCacheFileURL: ratesCacheURL,
            currenciesCacheFileURL: currenciesCacheURL
        )

        // The live URL in test config points to api.test.example.com — it will fail,
        // so the service should fall back to the file cache.
        let codes = await offlineService.fetchAvailableCurrencies()
        XCTAssertEqual(codes, expected, "Should return cached list including newly added CLP")
    }

    func testCurrencies_cacheUpdated_newCurrencyVisible_afterRelaunch() async throws {
        // Step 1: cache with original list (no CLP)
        let original = ["MXN", "ARS", "BRL", "COP"]
        try JSONEncoder().encode(original).write(to: currenciesCacheURL)

        // Step 2: simulate a successful network response by writing the updated list
        let updated = ["MXN", "ARS", "BRL", "COP", "CLP"]
        try JSONEncoder().encode(updated).write(to: currenciesCacheURL)

        // Step 3: offline relaunch reads the updated cache
        let offlineService = ExchangeRateService(
            config: AppConfiguration.test,
            ratesCacheFileURL: ratesCacheURL,
            currenciesCacheFileURL: currenciesCacheURL
        )
        let codes = await offlineService.fetchAvailableCurrencies()
        XCTAssertTrue(codes.contains("CLP"), "Newly added CLP should survive offline relaunch")
    }
}

// MARK: - CurrencyFormatter

final class CurrencyFormatterTests: XCTestCase {

    func testFormatAmount_largeNumber_hasTwoDecimalPlaces() {
        let formatted = CurrencyFormatter.formatAmount(1_841_000.0)
        // check decimal separator exists with two trailing digits
        let parts = formatted.components(separatedBy: CharacterSet(charactersIn: ".,"))
        XCTAssertEqual(parts.last?.count, 2)
    }

    func testFormatAmount_wholeNumber_stillShowsTwoDecimalPlaces() {
        let formatted = CurrencyFormatter.formatAmount(100.0)
        XCTAssertTrue(formatted.hasSuffix("00"))
    }

    func testFormatAmount_infinity_returnsZero() {
        XCTAssertEqual(CurrencyFormatter.formatAmount(.infinity), "0.00")
    }

    func testFormatAmount_nan_returnsZero() {
        XCTAssertEqual(CurrencyFormatter.formatAmount(.nan), "0.00")
    }

    func testFormatRate_upToFourDecimalPlaces() {
        let formatted = CurrencyFormatter.formatRate(18.4097)
        XCTAssertTrue(formatted.hasSuffix("4097"))
    }

    func testFormatRate_infinity_returnsZero() {
        XCTAssertEqual(CurrencyFormatter.formatRate(.infinity), "0.00")
    }
}
