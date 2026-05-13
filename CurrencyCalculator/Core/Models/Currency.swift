import Foundation

struct Currency: Identifiable, Hashable {
    let code: String
    let flag: String
    var id: String { code }
}

extension Currency {
    static let usdc = Currency(code: "USDc", flag: "🇺🇸")

    static func make(code: String) -> Currency {
        if code.caseInsensitiveCompare("usdc") == .orderedSame { return .usdc }
        let normalized = code.uppercased()
        return Currency(code: normalized, flag: flagEmoji(countryCode: String(normalized.prefix(2))))
    }

    /* Using this logic for this example but will be using better apprach like storing
     flag images and then consuming them.
     */
    
    private static func flagEmoji(countryCode: String) -> String {
        let base: UInt32 = 127397
        return countryCode.uppercased().unicodeScalars.compactMap {
            UnicodeScalar(base + $0.value).map(String.init)
        }.joined()
    }
}
