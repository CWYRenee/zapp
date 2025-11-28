import SwiftUI

struct EmailView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @FocusState private var isEmailFieldFocused: Bool

    var body: some View {
        VStack(spacing: ZapSpacing.lg) {
            Spacer()

            VStack(spacing: ZapSpacing.sm) {
                Text("Login / Sign Up")
                    .font(ZapTypography.titleFont)
                    .foregroundColor(ZapColors.primary)
                Text("Enter your email to get a one-time code.")
                    .font(ZapTypography.subtitleFont)
                    .multilineTextAlignment(.center)
                    .foregroundColor(ZapColors.textSecondary)
                    .padding(.horizontal, ZapSpacing.xl)
            }

            ZapTextField(
                title: "Email",
                placeholder: "you@example.com",
                text: $authViewModel.email,
                keyboardType: .emailAddress,
                isSecure: false
            )
            .focused($isEmailFieldFocused)

            if let error = authViewModel.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, ZapSpacing.base)
            }

            ZapButton(
                authViewModel.isSendingCode ? "Sending..." : "Send Code",
                isLoading: authViewModel.isSendingCode,
                isDisabled: !isValidEmail(authViewModel.email)
            ) {
                Task {
                    await authViewModel.sendCode()
                }
            }
            .padding(.top, ZapSpacing.base)

            Spacer()
        }
        .padding(.horizontal, ZapSpacing.xl)
        .background(ZapColors.background.ignoresSafeArea())
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isEmailFieldFocused = true
            }
        }
    }

    private func isValidEmail(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return trimmed.contains("@") && trimmed.contains(".")
    }
}
