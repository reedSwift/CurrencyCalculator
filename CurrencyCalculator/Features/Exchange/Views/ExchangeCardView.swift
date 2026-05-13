import SwiftUI

struct ExchangeCardView: View {

    @ObservedObject var viewModel: ExchangeViewModel
    @FocusState private var focusedField: FocusedField?

    private enum FocusedField { case top, bottom }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, DS.Spacing.horizontal)
                .padding(.top, DS.Spacing.headerTop)
                .padding(.bottom, DS.Spacing.headerBottom)

            cardStack
                .padding(.horizontal, DS.Spacing.horizontal)

            Spacer()
        }
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onChange(of: focusedField) { oldValue, newValue in
            guard let newFocus = newValue else { return }
            viewModel.fieldGainedFocus(isTop: newFocus == .top)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
                    .fontWeight(.semibold)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.headerStack) {
            Text(Strings.Exchange.screenTitle)
                .textStyle(DS.Typography.screenTitle)
                .foregroundStyle(DS.Colors.textPrimary)

            rateStatusView
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var rateStatusView: some View {
        switch viewModel.rateLoadState {
        case .loading:
            HStack(spacing: DS.Spacing.iconTextGap) {
                ProgressView().scaleEffect(0.8)
                Text(Strings.Exchange.loadingRates)
                    .textStyle(DS.Typography.label)
                    .foregroundStyle(Color(.secondaryLabel))
            }
            .frame(height: DS.Spacing.statusRowHeight, alignment: .leading)

        case .live:
            Text(viewModel.rateSubtitle)
                .textStyle(DS.Typography.rateSubtitle)
                .foregroundStyle(DS.Colors.brand)
                .frame(height: DS.Spacing.statusRowHeight, alignment: .leading)
                .accessibilityLabel(Strings.Accessibility.rateStatus)
                .accessibilityValue(viewModel.rateSubtitle)

        case .cached:
            HStack(spacing: DS.Spacing.iconTextGap) {
                Image(systemName: DS.Icons.wifiOff)
                    .font(DS.Typography.statusIcon)
                Text(viewModel.rateSubtitle)
                    .textStyle(DS.Typography.rateSubtitle)
            }
            .foregroundStyle(Color(.systemOrange))
            .frame(height: DS.Spacing.statusRowHeight, alignment: .leading)

        case .failed:
            HStack(spacing: DS.Spacing.iconTextGap) {
                Image(systemName: DS.Icons.warning)
                    .font(DS.Typography.statusIcon)
                    .foregroundStyle(Color(.systemRed))
                Text(Strings.Exchange.ratesUnavailable)
                    .textStyle(DS.Typography.label)
                    .foregroundStyle(Color(.systemRed))
                Button(Strings.Exchange.retry) { viewModel.retryFetch() }
                    .textStyle(DS.Typography.label)
                    .foregroundStyle(DS.Colors.brand)
            }
            .frame(height: DS.Spacing.statusRowHeight, alignment: .leading)
        }
    }

    // MARK: - Card stack

    /// Custom bindings route typed input through the ViewModel's sanitize+recompute
    /// pipeline *before* SwiftUI renders the value, so the TextField never displays
    /// an invalid string (e.g. more than 2 decimal places). Using $viewModel.topText
    /// directly lets SwiftUI render the raw keystroke first; the Combine sink corrects
    /// it a frame later, which is visible as a brief flicker / extra character.
    private var topTextBinding: Binding<String> {
        Binding(
            get: { viewModel.topText },
            set: { viewModel.handleTopTextChange($0) }
        )
    }

    private var bottomTextBinding: Binding<String> {
        Binding(
            get: { viewModel.bottomText },
            set: { viewModel.handleBottomTextChange($0) }
        )
    }

    /// Two white rounded cards stacked with a 2px gap, swap button centred between them.
    private var cardStack: some View {
        ZStack(alignment: .center) {
            VStack(spacing: DS.Spacing.cardGap) {
                currencyCard(
                    currency: viewModel.topCurrency,
                    text: topTextBinding,
                    isPickable: !viewModel.usdcIsOnTop,
                    focusTag: .top
                )
                currencyCard(
                    currency: viewModel.bottomCurrency,
                    text: bottomTextBinding,
                    isPickable: viewModel.usdcIsOnTop,
                    focusTag: .bottom
                )
            }

            swapButton
        }
    }

    // MARK: - Currency card

    private func currencyCard(
        currency: Currency,
        text: Binding<String>,
        isPickable: Bool,
        focusTag: FocusedField
    ) -> some View {
        HStack(spacing: DS.Spacing.rowGap) {
            if isPickable {
                Button { viewModel.requestPicker() } label: {
                    currencyLabel(currency: currency, showChevron: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Strings.Accessibility.selectCurrency(currency.code))
            } else {
                currencyLabel(currency: currency, showChevron: false)
                    .accessibilityHidden(true) // non-interactive label — amount field provides context
            }

            Spacer(minLength: 0)

            HStack(spacing: 2) {
                Text(Strings.Exchange.amountPrefix)
                    .textStyle(DS.Typography.amountInput)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .accessibilityHidden(true) // prefix is part of the field's semantic label
                TextField(Strings.Exchange.amountPlaceholder, text: text)
                    .keyboardType(.decimalPad)
                    .font(DS.Typography.amountInput.font)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .focused($focusedField, equals: focusTag)
                    .fixedSize(horizontal: true, vertical: false)
                    .multilineTextAlignment(.trailing)
                    .accessibilityLabel(Strings.Accessibility.amountField(currency.code))
            }
        }
        .padding(.horizontal, DS.Spacing.rowHorizontal)
        .frame(height: DS.Size.rowHeight)
        .background(DS.Colors.rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: DS.Size.rowRadius, style: .continuous))
    }

    private func currencyLabel(currency: Currency, showChevron: Bool) -> some View {
        HStack(spacing: DS.Spacing.iconTextGap) {
            Text(currency.flag)
                .font(DS.Typography.pickerFlag)
            Text(currency.code)
                .textStyle(DS.Typography.currencyCode)
                .foregroundStyle(DS.Colors.textPrimary)
            if showChevron {
                Image(systemName: DS.Icons.chevronDown)
                    .font(DS.Typography.chevron)
                    .foregroundStyle(DS.Colors.textPrimary)
            }
        }
    }

    // MARK: - Swap button
    //
    // Figma: 24×24 circle filled #22D081, with a 6px outer border ring of #F4F4F4.
    // Implemented as two concentric circles in a ZStack.

    private var swapButton: some View {
        Button {
            withAnimation(DS.Animation.swap) { viewModel.swap() }
        } label: {
            ZStack {
                Circle()
                    .fill(DS.Colors.swapRing)
                    .frame(width: DS.Size.swapTotal, height: DS.Size.swapTotal)
                Circle()
                    .fill(DS.Colors.brand)
                    .frame(width: DS.Size.swapButton, height: DS.Size.swapButton)
                Image(systemName: DS.Icons.arrowDown)
                    .font(DS.Typography.swapIcon)
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Strings.Accessibility.swapButton)
        .accessibilityHint(Strings.Accessibility.swapButtonHint)
    }
}
