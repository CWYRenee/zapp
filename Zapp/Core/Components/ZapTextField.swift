import SwiftUI
import UIKit

struct ZapTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.xs) {
            Text(title)
                .font(.caption)
                .foregroundColor(ZapColors.textSecondary)
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                }
            }
            .keyboardType(keyboardType)
            .padding(.vertical, ZapSpacing.sm)
            .padding(.horizontal, ZapSpacing.base)
            .background(
                RoundedRectangle(cornerRadius: ZapRadius.medium)
                    .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
}
