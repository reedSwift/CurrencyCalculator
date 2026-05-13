import SwiftUI

/// Central design system — pixel-matched to Figma "[EXT] Exchange Home Task".
///
/// Two-layer structure:
///   • Private base scale  — raw font/size/spacing primitives
///   • Public semantic tokens — named by role, reference the base scale
///
/// `DS` typealias keeps call sites concise:
///   .textStyle(DS.Typography.screenTitle)
///   .foregroundStyle(DS.Colors.brand)
///   .padding(.horizontal, DS.Spacing.horizontal)
typealias DS = DesignSystem

enum DesignSystem {

    // MARK: - Font registration
    //
    // Steps to activate Messina Sans in Xcode:
    //   1. Drag the .otf / .ttf files into the project (check "Copy if needed",
    //      tick the app target).
    //   2. Add each filename (e.g. "MessinaSansNarrow-Bold.otf") to Info.plist
    //      under the "Fonts provided by application" (UIAppFonts) array.
    //   3. Verify PostScript names match the strings below using Font Book → ⌘I.
    //
    // SwiftUI silently falls back to the system font when a custom font is not
    // found, so the app runs without crashing while the files are being sourced.

    enum FontName {
        static let narrowSemiBold   = "MessinaSansNarrow-SemiBold"  // weight 600
        static let narrowBold       = "MessinaSansNarrow-Bold"       // weight 700
        /// Picker sheet header uses the wider "Messina Sans", not the Narrow cut.
        static let semiBold         = "MessinaSans-SemiBold"
    }

    // MARK: - TextStyle
    //
    // Bundles Font + letter-spacing so a single `.textStyle()` call applies both.
    // Figma expresses letter-spacing as % of font size; SwiftUI's `.tracking()`
    // takes absolute points → tracking = size × (percent / 100).

    struct TextStyle {
        let font: Font
        /// Absolute letter-spacing in points.
        let tracking: CGFloat
    }

    // MARK: - Colors

    enum Colors {
        /// #22D081 — Figma token: Content/contentBrand
        static let brand          = Color(hex: "22D081")
        /// #2C2C2E — Figma token: Content/contentPrimary
        static let textPrimary    = Color(hex: "2C2C2E")
        /// Row card fill — white in light mode, elevated surface in dark mode.
        /// Using semantic color instead of #FFFFFF so dark mode works automatically.
        static let rowBackground  = Color(.secondarySystemGroupedBackground)
        /// Swap button outer ring — matches the screen background so the button
        /// appears to "float" between the two cards in both light and dark mode.
        static let swapRing       = Color(.systemGroupedBackground)
    }

    // MARK: - Typography

    enum Typography {

        // MARK: Private base scale
        // Build fonts once; semantic tokens reference these to make shared
        // scales explicit rather than coincidental copy-paste.

        private static func narrow(_ size: CGFloat, bold: Bool = false) -> Font {
            Font.custom(bold ? FontName.narrowBold : FontName.narrowSemiBold, size: size)
        }

        /// All body tokens: 16px semibold, +2% tracking (0.32pt)
        private static let _body = TextStyle(font: narrow(16), tracking: 0.32)

        /// Bold body: 16px bold, +2% tracking (0.32pt)
        private static let _bodyBold = TextStyle(font: narrow(16, bold: true), tracking: 0.32)

        // MARK: Semantic tokens

        /// "Exchange calculator" — Apps/Header/Header 3
        /// Messina Sans Narrow Bold, 30px, -2% tracking (-0.6pt)
        static let screenTitle  = TextStyle(font: narrow(30, bold: true), tracking: -0.6)

        /// Rate subtitle line — "1 USDc = 18.41 MXN"
        /// Color varies by state (.brand for live, .systemOrange for cached, etc.)
        static let rateSubtitle = _body

        /// Currency code in exchange rows — "USDc", "MXN"
        static let currencyCode = _body

        /// Amount input field — "$9,999", "$184,065.59"
        static let amountInput  = _bodyBold

        /// Standard label: picker row codes, dismiss icon, status body copy
        static let label        = _body

        /// "Choose currency" — Apps/Header/Header 4
        /// Messina Sans (not Narrow), 24px, -2% tracking (-0.48pt)
        static let pickerTitle  = TextStyle(
            font: Font.custom(FontName.semiBold, size: 24),
            tracking: -0.48
        )

        // SF Symbol icons — no custom font, no tracking needed.
        // Using system font for glyphs that appear in icon-only contexts.
        static let statusIcon   = Font.system(size: 12, weight: .medium)
        static let chevron      = Font.system(size: 11, weight: .medium)
        static let swapIcon     = Font.system(size: 13, weight: .bold)
        static let selectionMark = Font.system(size: 22)
        static let dismiss      = Font.system(size: 15, weight: .medium)
        static let pickerFlag   = Font.system(size: 28)
    }

    // MARK: - Spacing

    enum Spacing {
        /// Standard screen-edge horizontal margin
        static let horizontal: CGFloat          = 20

        /// Row card internal horizontal padding (Figma: 16px left/right)
        static let rowHorizontal: CGFloat       = 16

        /// Row card internal vertical padding (Figma: 12px top/bottom)
        static let rowVertical: CGFloat         = 12

        /// Gap between currency label and amount inside a row (Figma: 16px)
        static let rowGap: CGFloat              = 16

        /// Vertical gap between the two stacked row cards —
        /// swap button sits in this gap
        static let cardGap: CGFloat             = 2

        /// Top padding above the header
        static let headerTop: CGFloat           = 24

        /// Bottom padding below the header, above the card stack
        static let headerBottom: CGFloat        = 20

        /// Gap between screen title and rate subtitle
        static let headerStack: CGFloat         = 6

        /// Gap between icon and text in status / picker rows
        static let iconTextGap: CGFloat         = 6

        /// Fixed height of the rate status row — prevents layout jumps on state change
        static let statusRowHeight: CGFloat     = 20

        /// Vertical padding inside the picker sheet header
        static let pickerHeaderVertical: CGFloat = 18

        /// Vertical padding inside each picker currency list row
        static let pickerRowVertical: CGFloat   = 14

        /// Gap between flag and currency code in the picker list
        static let pickerRowInner: CGFloat      = 14
    }

    // MARK: - Size

    enum Size {
        /// Row card fixed height — Figma: 66px
        static let rowHeight: CGFloat           = 66

        /// Row card corner radius — Figma: 16px
        static let rowRadius: CGFloat           = 16

        /// Green inner circle of the swap button — Figma: 24×24px
        static let swapButton: CGFloat          = 24

        /// White outer border ring on the swap button — Figma: 6px border
        static let swapRing: CGFloat            = 6

        /// Total visual diameter of the swap button including the ring
        static let swapTotal: CGFloat           = swapButton + swapRing * 2  // 36px

        /// Dismiss button touch target
        static let dismissButton: CGFloat       = 30

        /// Selection indicator circle in the picker
        static let selectionIndicator: CGFloat  = 22

        /// Stroke width of the unselected ring in the picker
        static let selectionStroke: CGFloat     = 1.5
    }

    // MARK: - Animation

    enum Animation {
        /// Spring used for the currency swap transition
        static let swap = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.7)
    }

    // MARK: - Icons

    enum Icons {
        static let wifiOff          = "wifi.slash"
        static let warning          = "exclamationmark.triangle"
        static let chevronDown      = "chevron.down"
        static let arrowDown        = "arrow.down"
        static let dismiss          = "xmark"
        static let checkmarkFilled  = "checkmark.circle.fill"
    }
}

// MARK: - View + TextStyle

extension View {
    /// Applies the font from a `DS.TextStyle`.
    /// For `Text`, prefer the `Text.textStyle(_:)` overload which also applies tracking.
    func textStyle(_ style: DS.TextStyle) -> some View {
        self.font(style.font)
    }
}

extension Text {
    /// Applies both font and letter-spacing (tracking) from a `DS.TextStyle`.
    func textStyle(_ style: DS.TextStyle) -> Text {
        self.font(style.font).tracking(style.tracking)
    }
}

// MARK: - Color hex initialiser

extension Color {
    /// Creates a `Color` from a 6-character hex string (e.g. `"22D081"`).
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8)  & 0xFF) / 255
        let b = Double( value        & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b)
    }
}
