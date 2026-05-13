import XCTest
import Combine
@testable import CurrencyCalculator

@MainActor
final class ExchangeViewModelTests: XCTestCase {

    private var mock: MockExchangeRateService!
    private var vm: ExchangeViewModel!

    override func setUp() async throws {
        try await super.setUp()
        mock = MockExchangeRateService()
        vm = ExchangeViewModel(service: mock, initialCurrencies: AppConfiguration.test.fallbackCurrencies)
        // Drain the async init task — mock methods return immediately so a few
        // cooperative yields are enough to let loadInitialData() finish.
        await Task.yield()
        await Task.yield()
        await Task.yield()
    }

    override func tearDown() async throws {
        vm = nil
        mock = nil
        try await super.tearDown()
    }

    // MARK: - Initial state

    func testInitialState_rateIsLive() {
        XCTAssertEqual(vm.rateLoadState, .live)
    }

    func testInitialState_usdcIsOnTop() {
        XCTAssertTrue(vm.usdcIsOnTop)
        XCTAssertEqual(vm.topCurrency, .usdc)
    }

    func testInitialState_selectedCurrencyIsFirstFromConfig() {
        XCTAssertEqual(vm.selectedCurrency.code, "MXN")
        XCTAssertEqual(vm.bottomCurrency.code, "MXN")
    }

    func testInitialState_subtitleReflectsUSDcToSelected() {
        XCTAssertTrue(vm.rateSubtitle.hasPrefix("1 USDc"))
        XCTAssertTrue(vm.rateSubtitle.contains("MXN"))
    }

    func testInitialState_availableCurrenciesMatchMock() {
        XCTAssertEqual(vm.availableCurrencies.map(\.code), ["MXN", "ARS", "BRL", "COP"])
    }

    func testInitialState_availableCurrenciesDoNotIncludeUSDc() {
        XCTAssertFalse(vm.availableCurrencies.contains(.usdc))
    }

    // MARK: - Bidirectional conversion (USDc top, MXN bottom)

    func testTopToBottom_USDcTop_multipliesByRate() {
        // 100 USDc × 18.41 MXN/USDc = 1841 MXN
        vm.handleTopTextChange("100")
        XCTAssertEqual(parsedDouble(vm.bottomText), 1841.0, accuracy: 0.01)
    }

    func testBottomToTop_USDcTop_dividesByRate() {
        // 1841 MXN ÷ 18.41 = ~100 USDc
        vm.handleBottomTextChange("1841")
        XCTAssertEqual(parsedDouble(vm.topText), 100.0, accuracy: 0.1)
    }

    func testTopToBottom_emptyInput_producesZero() {
        vm.handleTopTextChange("100")
        vm.handleTopTextChange("")
        XCTAssertEqual(parsedDouble(vm.bottomText), 0.0, accuracy: 0.01)
    }

    // MARK: - Swap

    func testSwap_exchangesCurrencyPositions() {
        vm.swap()
        XCTAssertEqual(vm.topCurrency.code, "MXN")
        XCTAssertEqual(vm.bottomCurrency.code, "USDc")
        XCTAssertFalse(vm.usdcIsOnTop)
    }

    func testSwap_exchangesTextValues() {
        vm.handleTopTextChange("100")
        let computedBottom = vm.bottomText
        vm.swap()
        XCTAssertEqual(vm.topText, computedBottom)
        XCTAssertEqual(vm.bottomText, "100")
    }

    func testSwap_doesNotTriggerSpuriousRecompute() {
        vm.handleTopTextChange("100")
        let bottomBeforeSwap = vm.bottomText

        vm.swap()

        XCTAssertEqual(vm.topText, bottomBeforeSwap)
        XCTAssertEqual(vm.bottomText, "100")
    }

    func testSwap_subtitle_remainsUSDcBased() {
        let subtitleBeforeSwap = vm.rateSubtitle
        vm.swap()
        XCTAssertEqual(vm.rateSubtitle, subtitleBeforeSwap)
        XCTAssertTrue(vm.rateSubtitle.hasPrefix("1 USDc"))
        XCTAssertTrue(vm.rateSubtitle.contains("MXN"))
    }

    func testDoubleSwap_restoresOriginalState() {
        vm.handleTopTextChange("100")
        let originalBottom = vm.bottomText
        vm.swap()
        vm.swap()
        XCTAssertEqual(vm.topText, "100")
        XCTAssertEqual(vm.bottomText, originalBottom)
        XCTAssertEqual(vm.topCurrency, .usdc)
        XCTAssertTrue(vm.usdcIsOnTop)
    }

    func testSwapThenEdit_recomputesCorrectly() {
        vm.handleTopTextChange("100")
        vm.swap()

        vm.handleTopTextChange("200")
        let expected = 200.0 / 18.41
        XCTAssertEqual(parsedDouble(vm.bottomText), expected, accuracy: 0.01)
    }

    // MARK: - Currency selection

    func testSelectCurrency_updatesSelectedCurrency() {
        vm.requestPicker()
        vm.selectCurrency(Currency(code: "ARS", flag: "🇦🇷"))
        XCTAssertEqual(vm.selectedCurrency.code, "ARS")
        XCTAssertTrue(vm.usdcIsOnTop)
        XCTAssertEqual(vm.topCurrency, .usdc)
        XCTAssertEqual(vm.bottomCurrency.code, "ARS")
    }

    func testSelectCurrency_afterSwap_updatesCorrectSide() {
        vm.swap()
        vm.requestPicker()
        vm.selectCurrency(Currency(code: "BRL", flag: "🇧🇷"))
        XCTAssertEqual(vm.selectedCurrency.code, "BRL")
        XCTAssertFalse(vm.usdcIsOnTop)
        XCTAssertEqual(vm.topCurrency.code, "BRL")
        XCTAssertEqual(vm.bottomCurrency, .usdc)
    }

    func testPickerSelectedCurrency_isSelectedCurrency() {
        XCTAssertEqual(vm.pickerSelectedCurrency, vm.selectedCurrency)
        vm.requestPicker()
        vm.selectCurrency(Currency(code: "COP", flag: "🇨🇴"))
        XCTAssertEqual(vm.pickerSelectedCurrency.code, "COP")
    }

    // MARK: - Input sanitization

    func testSanitize_stripsLetters() {
        vm.handleTopTextChange("abc123")
        XCTAssertEqual(vm.topText, "123")
    }

    func testSanitize_stripsSpecialChars() {
        vm.handleTopTextChange("$1,000")
        XCTAssertEqual(vm.topText, "1000")
    }

    func testSanitize_allowsOneDecimalPoint() {
        vm.handleTopTextChange("12.34.56")
        XCTAssertEqual(vm.topText, "12.34")
    }

    func testSanitize_limitsToTwoDecimalPlaces() {
        vm.handleTopTextChange("12.345")
        XCTAssertEqual(vm.topText, "12.34")
    }

    func testSanitize_allowsValidDecimal() {
        vm.handleTopTextChange("100.50")
        XCTAssertEqual(vm.topText, "100.50")
    }

    // MARK: - Leading zeros

    func testSanitize_stripsLeadingZeros() {
        vm.handleTopTextChange("007")
        XCTAssertEqual(vm.topText, "7")
    }

    func testSanitize_stripsLeadingZeros_withDecimal() {
        vm.handleTopTextChange("007.50")
        XCTAssertEqual(vm.topText, "7.50")
    }

    func testSanitize_preservesSingleZero() {
        vm.handleTopTextChange("0")
        XCTAssertEqual(vm.topText, "0")
    }

    func testSanitize_preservesZeroBeforeDecimal() {
        vm.handleTopTextChange("0.50")
        XCTAssertEqual(vm.topText, "0.50")
    }

    // MARK: - Max integer digits

    func testSanitize_capsAtTenIntegerDigits() {
        vm.handleTopTextChange("12345678901") // 11 digits
        XCTAssertEqual(vm.topText, "1234567890") // capped at 10
    }

    func testSanitize_allowsExactlyTenIntegerDigits() {
        vm.handleTopTextChange("1234567890")
        XCTAssertEqual(vm.topText, "1234567890")
    }

    func testSanitize_capDoesNotAffectDecimalPart() {
        vm.handleTopTextChange("1234567890.99")
        XCTAssertEqual(vm.topText, "1234567890.99")
    }

    // MARK: - Offline: valid cache

    func testOffline_validCache_setsStateToCached() async throws {
        mock.ratesResult = RateResult(
            rates: ["MXN": 18.41],
            source: .cached,
            fetchedAt: Date()
        )
        let offlineVM = ExchangeViewModel(service: mock, initialCurrencies: AppConfiguration.test.fallbackCurrencies)
        await Task.yield(); await Task.yield(); await Task.yield()
        XCTAssertEqual(offlineVM.rateLoadState, .cached)
    }

    func testOffline_cachedSubtitle_includesCachedPrefix() async throws {
        mock.ratesResult = RateResult(
            rates: ["MXN": 18.41],
            source: .cached,
            fetchedAt: Date()
        )
        let offlineVM = ExchangeViewModel(service: mock, initialCurrencies: AppConfiguration.test.fallbackCurrencies)
        await Task.yield(); await Task.yield(); await Task.yield()
        XCTAssertTrue(offlineVM.rateSubtitle.contains("(cached"))
    }

    // MARK: - Offline: stale / no cache

    func testOffline_noValidCache_setsStateFailed() async throws {
        mock.ratesResult = nil
        let failedVM = ExchangeViewModel(service: mock, initialCurrencies: AppConfiguration.test.fallbackCurrencies)
        await Task.yield(); await Task.yield(); await Task.yield()
        guard case .failed = failedVM.rateLoadState else {
            return XCTFail("Expected .failed, got \(failedVM.rateLoadState)")
        }
    }

    func testOffline_noValidCache_subtitleIsEmpty() async throws {
        mock.ratesResult = nil
        let failedVM = ExchangeViewModel(service: mock, initialCurrencies: AppConfiguration.test.fallbackCurrencies)
        await Task.yield(); await Task.yield(); await Task.yield()
        XCTAssertTrue(failedVM.rateSubtitle.isEmpty)
    }

    func testRetryFetch_recoversToLiveState() async throws {
        mock.ratesResult = nil
        let failedVM = ExchangeViewModel(service: mock, initialCurrencies: AppConfiguration.test.fallbackCurrencies)
        await Task.yield(); await Task.yield(); await Task.yield()

        mock.ratesResult = RateResult(rates: ["MXN": 18.41], source: .live, fetchedAt: Date())
        failedVM.retryFetch()
        await Task.yield(); await Task.yield(); await Task.yield()
        XCTAssertEqual(failedVM.rateLoadState, .live)
    }

    // MARK: - Picker signal

    func testRequestPicker_sendsSignal() {
        var received = false
        let cancellable = vm.showPickerPublisher.sink { received = true }
        vm.requestPicker()
        XCTAssertTrue(received)
        cancellable.cancel()
    }

    // MARK: - Helpers

    private func parsedDouble(_ text: String) -> Double {
        Double(text.replacingOccurrences(of: ",", with: "")) ?? 0
    }
}
