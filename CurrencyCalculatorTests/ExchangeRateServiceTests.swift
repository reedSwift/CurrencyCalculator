import XCTest
@testable import CurrencyCalculator

@MainActor
final class ExchangeRateServiceNetworkTests: XCTestCase {

    private var ratesCacheURL: URL!
    private var currenciesCacheURL: URL!
    private var session: URLSession!
    private var service: ExchangeRateService!

    // MARK: - Fixtures

    private static let tickersJSON = """
    [{"ask":"18.42","bid":"18.40","book":"usdc_mxn","date":"2025-10-20T20:14:57Z"},
     {"ask":"1550.00","bid":"1540.00","book":"usdc_ars","date":"2025-10-20T20:14:57Z"}]
    """.data(using: .utf8)!

    private static let currenciesJSON = """
    ["MXN","ARS","BRL","COP","CLP"]
    """.data(using: .utf8)!

    private func okResponse() -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://example.com")!,
                        statusCode: 200, httpVersion: nil, headerFields: nil)!
    }

    // MARK: - Setup / teardown

    override func setUp() async throws {
        try await super.setUp()
        let tmp = FileManager.default.temporaryDirectory
        ratesCacheURL      = tmp.appendingPathComponent(UUID().uuidString + "_rates.json")
        currenciesCacheURL = tmp.appendingPathComponent(UUID().uuidString + "_currencies.json")

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)

        service = ExchangeRateService(
            config: AppConfiguration.test,
            session: session,
            ratesCacheFileURL: ratesCacheURL,
            currenciesCacheFileURL: currenciesCacheURL
        )
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: ratesCacheURL)
        try? FileManager.default.removeItem(at: currenciesCacheURL)
        MockURLProtocol.requestHandler = nil
        service = nil
        session = nil
        try await super.tearDown()
    }

    // MARK: - Rates: live fetch

    func testFetchRates_success_returnsLiveSource() async {
        MockURLProtocol.requestHandler = { [ok = okResponse()] _ in (ok, Self.tickersJSON) }
        let result = await service.fetchRates(for: ["MXN", "ARS"])
        XCTAssertEqual(result?.source, .live)
    }

    func testFetchRates_success_parsesRatesCorrectly() async {
        MockURLProtocol.requestHandler = { [ok = okResponse()] _ in (ok, Self.tickersJSON) }
        let result = await service.fetchRates(for: ["MXN"])
        // mid = (18.42 + 18.40) / 2 = 18.41
        XCTAssertEqual(result?.rates["MXN"] ?? 0, 18.41, accuracy: 0.001)
    }

    func testFetchRates_success_writesCache() async {
        MockURLProtocol.requestHandler = { [ok = okResponse()] _ in (ok, Self.tickersJSON) }
        _ = await service.fetchRates(for: ["MXN"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: ratesCacheURL.path),
                      "Successful fetch should persist cache file")
    }

    // MARK: - Rates: offline fallback

    func testFetchRates_networkFailure_noCache_returnsNil() async {
        MockURLProtocol.requestHandler = { _ in throw URLError(.notConnectedToInternet) }
        let result = await service.fetchRates(for: ["MXN"])
        XCTAssertNil(result, "No cache + network failure should return nil")
    }

    func testFetchRates_networkFailure_validCache_returnsCachedSource() async throws {
        try seedRatesCache(rates: ["MXN": 18.41], ageSeconds: 0)
        MockURLProtocol.requestHandler = { _ in throw URLError(.notConnectedToInternet) }
        let result = await service.fetchRates(for: ["MXN"])
        XCTAssertEqual(result?.source, .cached)
        XCTAssertEqual(result?.rates["MXN"] ?? 0, 18.41, accuracy: 0.001)
    }

    func testFetchRates_networkFailure_staleCache_returnsNil() async throws {
        // Cache is 25 hours old — beyond the 24h max age in AppConfiguration.test
        try seedRatesCache(rates: ["MXN": 18.41], ageSeconds: 25 * 3_600)
        MockURLProtocol.requestHandler = { _ in throw URLError(.notConnectedToInternet) }
        let result = await service.fetchRates(for: ["MXN"])
        XCTAssertNil(result, "Cache older than cacheMaxAge should be rejected")
    }

    // MARK: - Currencies: live fetch

    func testFetchCurrencies_success_returnsDecodedList() async {
        MockURLProtocol.requestHandler = { [ok = okResponse()] _ in (ok, Self.currenciesJSON) }
        let codes = await service.fetchAvailableCurrencies()
        XCTAssertEqual(codes, ["MXN", "ARS", "BRL", "COP", "CLP"])
    }

    func testFetchCurrencies_success_writesCache() async {
        MockURLProtocol.requestHandler = { [ok = okResponse()] _ in (ok, Self.currenciesJSON) }
        _ = await service.fetchAvailableCurrencies()
        XCTAssertTrue(FileManager.default.fileExists(atPath: currenciesCacheURL.path),
                      "Successful fetch should persist currencies cache")
    }

    // MARK: - Currencies: offline fallback

    func testFetchCurrencies_networkFailure_returnsCachedList() async throws {
        let cached = ["MXN", "ARS", "BRL"]
        try JSONEncoder().encode(cached).write(to: currenciesCacheURL)
        MockURLProtocol.requestHandler = { _ in throw URLError(.notConnectedToInternet) }
        let codes = await service.fetchAvailableCurrencies()
        XCTAssertEqual(codes, cached)
    }

    func testFetchCurrencies_networkFailure_noCache_returnsBundleFallback() async {
        MockURLProtocol.requestHandler = { _ in throw URLError(.notConnectedToInternet) }
        let codes = await service.fetchAvailableCurrencies()
        // Bundle.main in a hosted test IS the app bundle — currencies.json is present
        XCTAssertFalse(codes.isEmpty, "Bundle fallback should provide currencies")
    }

    // MARK: - Helpers

    /// Writes a `CachedRates` fixture to `ratesCacheURL` with the given age.
    private func seedRatesCache(rates: [String: Double], ageSeconds: TimeInterval) throws {
        let fetchedAt = Date().addingTimeInterval(-ageSeconds)
        let data = try JSONEncoder().encode(CachedRates(rates: rates, fetchedAt: fetchedAt))
        try data.write(to: ratesCacheURL)
    }
}

// MARK: - CurrencyConverter tests

final class CurrencyConverterTests: XCTestCase {

    func testConvert_fromUSDc_multipliesByRate() {
        let result = CurrencyConverter.convert(amount: 100, rate: 18.41, fromUSDc: true)
        XCTAssertEqual(NSDecimalNumber(decimal: result).doubleValue, 1841.0, accuracy: 0.01)
    }

    func testConvert_toUSDc_dividesByRate() {
        let result = CurrencyConverter.convert(amount: 1841, rate: 18.41, fromUSDc: false)
        XCTAssertEqual(NSDecimalNumber(decimal: result).doubleValue, 100.0, accuracy: 0.01)
    }

    func testConvert_zeroRate_returnsZero() {
        let result = CurrencyConverter.convert(amount: 100, rate: 0, fromUSDc: true)
        XCTAssertEqual(result, 0)
    }

    func testConvert_negativeRate_returnsZero() {
        let result = CurrencyConverter.convert(amount: 100, rate: -5, fromUSDc: true)
        XCTAssertEqual(result, 0)
    }

    func testConvert_zeroAmount_returnsZero() {
        let result = CurrencyConverter.convert(amount: 0, rate: 18.41, fromUSDc: true)
        XCTAssertEqual(result, 0)
    }
}
