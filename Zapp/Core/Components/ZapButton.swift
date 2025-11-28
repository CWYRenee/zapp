import SwiftUI

struct ZapButton: View {
    enum Style {
        case primary
        case secondary
    }

    let title: String
    let style: Style
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    init(
        _ title: String,
        style: Style = .primary,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .tint(style == .primary ? Color.white : ZapColors.primary)
                }
                Text(title)
                    .font(ZapTypography.buttonFont)
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical, ZapSpacing.md)
            .padding(.horizontal, ZapSpacing.base)
            .foregroundColor(style == .primary ? Color.white : ZapColors.primary)
            .background(background)
            .cornerRadius(ZapRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: ZapRadius.medium)
                    .stroke(style == .secondary ? ZapColors.primary : Color.clear, lineWidth: 1)
            )
        }
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled || isLoading ? 0.6 : 1.0)
    }

    private var background: Color {
        switch style {
        case .primary:
            return ZapColors.primary
        case .secondary:
            return Color.clear
        }
    }
}
