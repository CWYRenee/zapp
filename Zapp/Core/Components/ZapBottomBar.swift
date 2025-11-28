import SwiftUI

struct ZapBottomBar: View {
    let primaryTitle: String
    let isPrimaryLoading: Bool
    let isPrimaryDisabled: Bool
    let onBack: () -> Void
    let onPrimary: () -> Void

    init(
        primaryTitle: String,
        isPrimaryLoading: Bool = false,
        isPrimaryDisabled: Bool = false,
        onBack: @escaping () -> Void,
        onPrimary: @escaping () -> Void
    ) {
        self.primaryTitle = primaryTitle
        self.isPrimaryLoading = isPrimaryLoading
        self.isPrimaryDisabled = isPrimaryDisabled
        self.onBack = onBack
        self.onPrimary = onPrimary
    }

    var body: some View {
        HStack(spacing: ZapSpacing.base) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(ZapColors.primary)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(Color(.secondarySystemBackground))
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            ZapButton(
                primaryTitle,
                isLoading: isPrimaryLoading,
                isDisabled: isPrimaryDisabled
            ) {
                onPrimary()
            }
        }
    }
}
