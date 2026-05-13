import Foundation

enum CurrencyFormatter {

    // Cached formatters — NumberFormatter is expensive to instantiate
    private static let amountFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    private static let rateFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 4
        return f
    }()

    /// Formats a converted amount, e.g. "1,841.00"
    static func formatAmount(_ value: Double) -> String {
        guard value.isFinite else { return "0.00" }
        return amountFormatter.string(from: NSNumber(value: value))
            ?? String(format: "%.2f", value)
    }

    /// Formats an exchange rate with up to 4 decimal places, e.g. "18.4097"
    static func formatRate(_ value: Double) -> String {
        guard value.isFinite else { return "0.00" }
        return rateFormatter.string(from: NSNumber(value: value))
            ?? String(format: "%.4f", value)
    }
}
