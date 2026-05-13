import Foundation
import Combine

enum RateLoadState: Equatable {
    case loading
    case live
    case cached
    case failed
}

@MainActor
final class ExchangeViewModel: ObservableObject {

    // MARK: - Published state

    @Published private(set) var selectedCurrency: Currency
    @Published private(set) var usdcIsOnTop: Bool = true
    @Published private(set) var availableCurrencies: [Currency] = []
    @Published var topText: String = ""
    @Published var bottomText: String = ""
    @Published private(set) var rateSubtitle: String = ""
    @Published private(set) var rateLoadState: RateLoadState = .loading

    let showPickerPublisher = PassthroughSubject<Void, Never>()

    var topCurrency: Currency { usdcIsOnTop ? .usdc : selectedCurrency }
    var bottomCurrency: Currency { usdcIsOnTop ? selectedCurrency : .usdc }
    var pickerSelectedCurrency: Currency { selectedCurrency }

    // MARK: - Private

    private enum ActiveField { case top, bottom }
    private var activeField: ActiveField = .top
    // True during any programmatic write to topText/bottomText.
    // @Published fires subscribers synchronously, so this flag is still set
    // when the subscriber for the OTHER field runs — preventing feedback loops.
    private var isRecomputing = false
    private var rates: [String: Double] = [:]
    private var lastFetchedAt: Date?
    private var cancellables = Set<AnyCancellable>()
    private let service: ExchangeRateServiceProtocol
    /// Retained so any in-flight fetch can be cancelled before starting a new one.
    /// Prevents concurrent writes to `rates` / `rateLoadState` when the user
    /// taps Retry rapidly or selects currencies in quick succession.
    /// `private(set)` so tests can `await fetchTask?.value` for deterministic sync.
    private(set) var fetchTask: Task<Void, Never>?

    // MARK: - Init

    init(
        service: ExchangeRateServiceProtocol,
        initialCurrencies: [Currency]
    ) {
        self.service = service
        self.availableCurrencies = initialCurrencies
        self.selectedCurrency = initialCurrencies.first ?? Currency(code: "MXN", flag: "🇲🇽")
        setupTextSubscriptions()
        fetchTask = Task { await loadInitialData() }
    }

    // MARK: - Text subscriptions
    //
    // Combine rather than SwiftUI onChange because @Published fires synchronously —
    // isRecomputing is still true when the opposite field's subscriber fires during
    // recompute(), blocking the feedback loop. SwiftUI onChange fires after defer
    // resets the flag, so it never protected anything.

    private func setupTextSubscriptions() {
        // Route SwiftUI field changes through the same handle methods used by tests
        // so there is exactly one code path for sanitization and recomputation.
        // Note: @Published on @MainActor does NOT replay the current value at
        // subscription time in Swift 6 / Xcode 26 — do NOT add dropFirst() here.
        $topText
            .sink { [weak self] in self?.handleTopTextChange($0) }
            .store(in: &cancellables)

        $bottomText
            .sink { [weak self] in self?.handleBottomTextChange($0) }
            .store(in: &cancellables)
    }

    // MARK: - Public text entry points
    // Used by tests (and optionally UIKit hosts). Sanitizes inline rather than
    // relying on the Combine subscription, so callers see consistent state immediately.

    func handleTopTextChange(_ newValue: String) {
        guard !isRecomputing else { return }
        isRecomputing = true
        defer { isRecomputing = false }
        topText = sanitize(newValue)
        activeField = .top
        recompute()
    }

    func handleBottomTextChange(_ newValue: String) {
        guard !isRecomputing else { return }
        isRecomputing = true
        defer { isRecomputing = false }
        bottomText = sanitize(newValue)
        activeField = .bottom
        recompute()
    }

    // MARK: - Actions

    func swap() {
        isRecomputing = true
        defer { isRecomputing = false }

        usdcIsOnTop.toggle()
        Swift.swap(&topText, &bottomText)
        activeField = activeField == .top ? .bottom : .top
        updateRateSubtitle()
    }

    func fieldGainedFocus(isTop: Bool) {
        guard !isRecomputing else { return }
        let tappedComputedField = isTop ? activeField == .bottom : activeField == .top
        guard tappedComputedField else { return }
        isRecomputing = true
        defer { isRecomputing = false }
        if isTop { topText = "" } else { bottomText = "" }
    }

    func requestPicker() {
        showPickerPublisher.send()
    }

    func selectCurrency(_ currency: Currency) {
        selectedCurrency = currency
        updateRateSubtitle()
        systemRecompute()
        if rates[currency.code] == nil {
            fetchTask?.cancel()
            fetchTask = Task { await fetchRates() }
        }
    }

    func retryFetch() {
        rateLoadState = .loading
        fetchTask?.cancel()
        fetchTask = Task { await fetchRates() }
    }

    /// Called when the app returns to the foreground. Silently refreshes rates
    /// so the user never sees stale data without realising it.
    func refreshIfNeeded() {
        guard rateLoadState != .loading else { return }
        fetchTask?.cancel()
        fetchTask = Task { await fetchRates() }
    }

    // MARK: - Data loading

    private func loadInitialData() async {
        rateLoadState = .loading
        let codes = await service.fetchAvailableCurrencies()
        let currencies = codes.isEmpty
            ? availableCurrencies
            : codes.map { Currency.make(code: $0) }
        availableCurrencies = currencies
        if !currencies.contains(selectedCurrency) {
            selectedCurrency = currencies.first ?? selectedCurrency
        }
        await fetchRates()
    }

    private func fetchRates() async {
        guard let result = await service.fetchRates(for: availableCurrencies.map(\.code)) else {
            rateLoadState = .failed
            return
        }
        rates.merge(result.rates) { _, new in new }
        lastFetchedAt = result.fetchedAt
        rateLoadState = result.source == .live ? .live : .cached
        updateRateSubtitle()
        systemRecompute()
    }

    // MARK: - Calculation

    private var selectedRate: Double { rates[selectedCurrency.code] ?? 0 }

    private func systemRecompute() {
        isRecomputing = true
        recompute()
        isRecomputing = false
    }

    private func recompute() {
        let rate = selectedRate
        guard rate > 0 else { return }

        switch activeField {
        case .top:
            bottomText = formatDecimal(CurrencyConverter.convert(
                amount: parseAmount(topText),
                rate: rate,
                fromUSDc: usdcIsOnTop
            ))
        case .bottom:
            topText = formatDecimal(CurrencyConverter.convert(
                amount: parseAmount(bottomText),
                rate: rate,
                fromUSDc: !usdcIsOnTop
            ))
        }
    }

    private func updateRateSubtitle() {
        let rate = selectedRate
        guard rate > 0 else { return }
        let suffix: String
        if rateLoadState == .cached, let fetchedAt = lastFetchedAt {
            suffix = Strings.Exchange.cachedSuffix(age: formattedAge(since: fetchedAt))
        } else {
            suffix = ""
        }
        rateSubtitle = Strings.Exchange.rateSubtitle(
            rate: CurrencyFormatter.formatRate(rate),
            currencyCode: selectedCurrency.code
        ) + suffix
    }

    private func formattedAge(since date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return Strings.CacheAge.justNow }
        let minutes = seconds / 60
        if minutes < 60 { return Strings.CacheAge.minutes(minutes) }
        return Strings.CacheAge.hours(minutes / 60)
    }

    // MARK: - Formatting & sanitization

    private func parseAmount(_ text: String) -> Decimal {
        let stripped = text.replacingOccurrences(of: ",", with: "")
        return Decimal(string: stripped.isEmpty ? "0" : stripped) ?? 0
    }

    /// Maximum number of digits allowed before the decimal point.
    /// Prevents nonsensical inputs like 99999999999999.
    private static let maxIntegerDigits = 10

    private func sanitize(_ text: String) -> String {
        var result = ""
        var hasDecimal = false
        var integerDigits = 0
        var decimalsAfterPoint = 0

        for char in text {
            if char.isNumber {
                if hasDecimal {
                    guard decimalsAfterPoint < 2 else { continue }
                    decimalsAfterPoint += 1
                    result.append(char)
                } else {
                    guard integerDigits < Self.maxIntegerDigits else { continue }
                    integerDigits += 1
                    result.append(char)
                }
            } else if char == "." && !hasDecimal {
                result.append(char)
                hasDecimal = true
            }
        }

        return stripLeadingZeros(result)
    }

    /// Removes leading zeros from the integer part while preserving valid decimals.
    /// "007"  → "7"   |   "007.50" → "7.50"   |   "0.5" → "0.5"   |   "0" → "0"
    private func stripLeadingZeros(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        if let dotIndex = text.firstIndex(of: ".") {
            let intPart = String(text[..<dotIndex])
            let decPart = String(text[dotIndex...])
            return normalizedIntPart(intPart) + decPart
        }
        return normalizedIntPart(text)
    }

    private func normalizedIntPart(_ s: String) -> String {
        let stripped = String(s.drop(while: { $0 == "0" }))
        return stripped.isEmpty ? "0" : stripped
    }

    private func formatDecimal(_ value: Decimal) -> String {
        CurrencyFormatter.formatAmount(NSDecimalNumber(decimal: value).doubleValue)
    }
}
