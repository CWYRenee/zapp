import SwiftUI

struct CurrencySelectorView: View {
    @EnvironmentObject var currencyStore: CurrencyStore
    @Environment(\.dismiss) var dismiss
    @AppStorage("handPreference") private var handPreference: String = "right"
    
    private var isRightHanded: Bool { handPreference != "left" }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: ZapSpacing.base) {
                Text("Select Currency")
                    .font(ZapTypography.titleFont)
                    .foregroundColor(ZapColors.primary)
                    .padding(.horizontal, ZapSpacing.xl)
                    .padding(.top, ZapSpacing.xl)
                
                List(Currency.allCases) { currency in
                    Button {
                        currencyStore.selectedCurrency = currency
                        dismiss()
                    } label: {
                        HStack {
                            Text(currency.symbol)
                                .font(.headline)
                                .frame(width: 32)
                            
                            VStack(alignment: .leading) {
                                Text(currency.rawValue)
                                    .font(.body)
                                    .foregroundColor(ZapColors.textPrimary)
                                Text(currency.name)
                                    .font(.caption)
                                    .foregroundColor(ZapColors.textSecondary)
                            }
                            
                            Spacer()
                            
                            if currencyStore.selectedCurrency == currency {
                                Image(systemName: "checkmark")
                                    .foregroundColor(ZapColors.primary)
                            }
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
            
            // Bottom close button matching SendView pattern
            HStack {
                if isRightHanded {
                    Spacer()
                }
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(ZapColors.primary)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                
                if !isRightHanded {
                    Spacer()
                }
            }
            .padding(.horizontal, ZapSpacing.xl)
            .padding(.bottom, ZapSpacing.xl)
        }
        .background(ZapColors.background.ignoresSafeArea())
    }
}
