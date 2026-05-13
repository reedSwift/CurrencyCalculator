import Foundation

/// All user-facing strings in one place.
///
/// Rules:
///   • Every string a user can read lives here — no raw literals in views or view models.
///   • Parameterised strings are static functions, not format-string constants,
///     so the compiler checks argument types and counts.
///   • All strings are wired to `NSLocalizedString` — adding a Localizable.strings
///     file (or a String Catalog) for any language requires zero changes at call sites.
///
/// Namespaced by feature so adding a new screen = adding a new nested enum,
/// not searching through a flat list.

enum Strings {

    // MARK: - Exchange screen

    enum Exchange {
        static let screenTitle = NSLocalizedString(
            "exchange.screen_title",
            value: "Exchange calculator",
            comment: "Title shown at the top of the main exchange screen"
        )
        static let amountPrefix = NSLocalizedString(
            "exchange.amount_prefix",
            value: "$",
            comment: "Currency symbol prefix shown before the amount input field"
        )
        static let amountPlaceholder = NSLocalizedString(
            "exchange.amount_placeholder",
            value: "0",
            comment: "Placeholder shown in the amount input field when empty"
        )

        // MARK: Rate status row

        static let loadingRates = NSLocalizedString(
            "exchange.loading_rates",
            value: "Fetching rates…",
            comment: "Shown in the rate status row while exchange rates are loading"
        )
        static let ratesUnavailable = NSLocalizedString(
            "exchange.rates_unavailable",
            value: "Rates unavailable",
            comment: "Shown in the rate status row when rates could not be loaded"
        )
        static let retry = NSLocalizedString(
            "exchange.retry",
            value: "Retry",
            comment: "Button label to retry fetching exchange rates after a failure"
        )

        /// "1 USDc = 18.41 MXN"
        static func rateSubtitle(rate: String, currencyCode: String) -> String {
            String(format: NSLocalizedString(
                "exchange.rate_subtitle",
                value: "1 USDc = %@ %@",
                comment: "Live exchange rate line. First %@ = formatted rate, second %@ = currency code e.g. MXN"
            ), rate, currencyCode)
        }

        /// " (cached just now)" / " (cached 3m ago)"
        static func cachedSuffix(age: String) -> String {
            String(format: NSLocalizedString(
                "exchange.cached_suffix",
                value: " (cached %@)",
                comment: "Appended to the rate subtitle when showing cached data. %@ = age string e.g. '3m ago'"
            ), age)
        }
    }

    // MARK: - Currency picker sheet

    enum Picker {
        static let title = NSLocalizedString(
            "picker.title",
            value: "Choose currency",
            comment: "Title of the currency picker bottom sheet"
        )
    }

    // MARK: - Accessibility labels

    enum Accessibility {
        static let swapButton = NSLocalizedString(
            "accessibility.swap_button",
            value: "Swap currencies",
            comment: "Accessibility label for the swap button between the two currency fields"
        )
        static let swapButtonHint = NSLocalizedString(
            "accessibility.swap_button_hint",
            value: "Swaps the top and bottom currency positions",
            comment: "Accessibility hint for the swap button"
        )
        static let retryButton = NSLocalizedString(
            "accessibility.retry_button",
            value: "Retry fetching exchange rates",
            comment: "Accessibility label for the retry button shown on rate fetch failure"
        )
        static let dismissPicker = NSLocalizedString(
            "accessibility.dismiss_picker",
            value: "Dismiss currency picker",
            comment: "Accessibility label for the dismiss button on the currency picker sheet"
        )
        static let rateStatus = NSLocalizedString(
            "accessibility.rate_status",
            value: "Exchange rate status",
            comment: "Accessibility label for the rate status row"
        )

        static func selectCurrency(_ code: String) -> String {
            String(format: NSLocalizedString(
                "accessibility.select_currency",
                value: "%@, tap to change currency",
                comment: "Accessibility label for a tappable currency label. %@ = currency code e.g. MXN"
            ), code)
        }

        static func amountField(_ code: String) -> String {
            String(format: NSLocalizedString(
                "accessibility.amount_field",
                value: "Amount in %@",
                comment: "Accessibility label for an amount input field. %@ = currency code e.g. MXN"
            ), code)
        }

        static func currencyRow(_ code: String) -> String {
            String(format: NSLocalizedString(
                "accessibility.currency_row",
                value: "%@ currency row",
                comment: "Accessibility label for a row in the currency picker list. %@ = currency code"
            ), code)
        }
    }

    // MARK: - Cache age labels

    enum CacheAge {
        static let justNow = NSLocalizedString(
            "cache_age.just_now",
            value: "just now",
            comment: "Shown when cached data was fetched less than a minute ago"
        )

        /// "3m ago"
        static func minutes(_ m: Int) -> String {
            String(format: NSLocalizedString(
                "cache_age.minutes",
                value: "%dm ago",
                comment: "Cache age in minutes. %d = number of minutes e.g. '3m ago'"
            ), m)
        }

        /// "2h ago"
        static func hours(_ h: Int) -> String {
            String(format: NSLocalizedString(
                "cache_age.hours",
                value: "%dh ago",
                comment: "Cache age in hours. %d = number of hours e.g. '2h ago'"
            ), h)
        }
    }
}
