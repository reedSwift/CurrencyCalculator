import Foundation

/// Pure conversion logic — no state, no dependencies, trivially testable.
///
/// All arithmetic uses `Decimal` to avoid floating-point rounding errors
/// when displaying monetary values to users.
enum CurrencyConverter {

    /// Converts an amount between USDc and a fiat currency.
    ///
    /// - Parameters:
    ///   - amount: The source amount as a `Decimal`.
    ///   - rate: The USDc → fiat exchange rate (e.g. 18.41 for MXN).
    ///   - fromUSDc: `true` to convert USDc → fiat (multiply),
    ///               `false` to convert fiat → USDc (divide).
    /// - Returns: The converted amount, or `0` if `rate` is zero or negative.
    static func convert(amount: Decimal, rate: Double, fromUSDc: Bool) -> Decimal {
        guard rate > 0 else { return 0 }
        let decimalRate = Decimal(rate)
        return fromUSDc ? amount * decimalRate : amount / decimalRate
    }
}
