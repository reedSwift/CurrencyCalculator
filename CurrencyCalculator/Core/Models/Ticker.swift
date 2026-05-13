import Foundation

struct Ticker: Decodable {
    let ask: String
    let bid: String
    let book: String
    let date: String
}

extension Ticker {
    /// Currency code derived from book string: "usdc_mxn" → "MXN"
    var currencyCode: String? {
        let parts = book.split(separator: "_")
        guard parts.count == 2 else { return nil }
        return parts[1].uppercased()
    }

    /// Mid-point rate between ask and bid
    var midRate: Double? {
        guard let a = Double(ask), let b = Double(bid), a > 0, b > 0 else { return nil }
        return (a + b) / 2.0
    }
}
