import SwiftUI

struct HomeActionCard: View {
    let title: String
    let subtitle: String
    let systemImageName: String
    let tintColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: ZapSpacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: ZapRadius.small)
                        .fill(tintColor.opacity(0.1))
                        .frame(width: 48, height: 48)
                    Image(systemName: systemImageName)
                        .foregroundColor(tintColor)
                }

                Text(title)
                    .font(.headline)
                    .foregroundColor(ZapColors.textPrimary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(ZapColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(ZapSpacing.base)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: ZapRadius.medium)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(.plain)
    }
}
