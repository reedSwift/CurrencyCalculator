/// All user-facing strings in one place.
///
/// Rules:
///   • Every string a user can read lives here — no raw literals in views or view models.
///   • Parameterised strings are static functions, not format-string constants,
///     so the compiler checks argument types and counts.
///   • When localisation is added, replace each `static let / static func`
///     body with `NSLocalizedString(...)` without touching any call site.
///
/// Namespaced by feature so adding a new screen = adding a new nested enum,
/// not searching through a flat list.

enum Strings {

    // MARK: - Exchange screen

    enum Exchange {
        static let screenTitle       = "Exchange calculator"
        static let amountPrefix      = "$"
        static let amountPlaceholder = "0"

        // MARK: Rate status row

        static let loadingRates      = "Fetching rates…"
        static let ratesUnavailable  = "Rates unavailable"
        static let retry             = "Retry"

        /// "1 USDc = 18.41 MXN"
        static func rateSubtitle(rate: String, currencyCode: String) -> String {
            "1 USDc = \(rate) \(currencyCode)"
        }

        /// " (cached just now)" / " (cached 3m ago)"
        static func cachedSuffix(age: String) -> String {
            " (cached \(age))"
        }

        // MARK: Error messages (passed into RateLoadState.failed)

        static let offlineError = "Rates unavailable. Connect to the internet to continue."
    }

    // MARK: - Currency picker sheet

    enum Picker {
        static let title = "Choose currency"
    }

    // MARK: - Accessibility labels

    enum Accessibility {
        static let swapButton            = "Swap currencies"
        static let swapButtonHint        = "Swaps the top and bottom currency positions"
        static let retryButton           = "Retry fetching exchange rates"
        static let dismissPicker         = "Dismiss currency picker"
        static let rateStatus            = "Exchange rate status"

        static func selectCurrency(_ code: String) -> String {
            "\(code), tap to change currency"
        }
        static func amountField(_ code: String) -> String {
            "Amount in \(code)"
        }
        static func currencyRow(_ code: String) -> String {
            "\(code) currency row"
        }
    }

    // MARK: - Cache age labels

    enum CacheAge {
        static let justNow = "just now"

        /// "3m ago"
        static func minutes(_ m: Int) -> String { "\(m)m ago" }

        /// "2h ago"
        static func hours(_ h: Int) -> String { "\(h)h ago" }
    }
}
