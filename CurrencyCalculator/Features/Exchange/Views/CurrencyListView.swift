import SwiftUI

struct CurrencyListView: View {

    @ObservedObject var viewModel: ExchangeViewModel
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            currencyList
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Text(Strings.Picker.title)
                .textStyle(DS.Typography.pickerTitle)
                .foregroundStyle(DS.Colors.textPrimary)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: DS.Icons.dismiss)
                    .font(DS.Typography.dismiss)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .frame(width: DS.Size.dismissButton, height: DS.Size.dismissButton)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Strings.Accessibility.dismissPicker)
        }
        .padding(.horizontal, DS.Spacing.horizontal)
        .padding(.vertical, DS.Spacing.pickerHeaderVertical)
    }

    private var currencyList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.availableCurrencies) { currency in
                    CurrencyOptionRow(
                        currency: currency,
                        isSelected: currency == viewModel.pickerSelectedCurrency
                    ) {
                        viewModel.selectCurrency(currency)
                        onDismiss()
                    }
                    Divider().padding(.leading, DS.Spacing.horizontal)
                }
            }
        }
    }
}

// MARK: - Row

private struct CurrencyOptionRow: View {

    let currency: Currency
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.Spacing.pickerRowInner) {
                Text(currency.flag)
                    .font(DS.Typography.pickerFlag)
                Text(currency.code)
                    .textStyle(DS.Typography.label)
                    .foregroundStyle(DS.Colors.textPrimary)
                Spacer()
                selectionIndicator
            }
            .padding(.horizontal, DS.Spacing.horizontal)
            .padding(.vertical, DS.Spacing.pickerRowVertical)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var selectionIndicator: some View {
        Group {
            if isSelected {
                Image(systemName: DS.Icons.checkmarkFilled)
                    .font(DS.Typography.selectionMark)
                    .foregroundStyle(DS.Colors.brand)
            } else {
                Circle()
                    .stroke(Color(.systemGray4), lineWidth: DS.Size.selectionStroke)
                    .frame(width: DS.Size.selectionIndicator,
                           height: DS.Size.selectionIndicator)
            }
        }
    }
}
