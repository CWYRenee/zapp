import SwiftUI

struct OTPView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @FocusState private var isCodeFieldFocused: Bool

    var body: some View {
        VStack(spacing: ZapSpacing.lg) {
            Spacer()

            VStack(spacing: ZapSpacing.sm) {
                Text("Enter the code")
                    .font(ZapTypography.titleFont)
                    .foregroundColor(ZapColors.primary)
                Text("We sent a 6-digit code to \(authViewModel.email).")
                    .font(ZapTypography.subtitleFont)
                    .multilineTextAlignment(.center)
                    .foregroundColor(ZapColors.textSecondary)
                    .padding(.horizontal, ZapSpacing.xl)
            }

            VStack(alignment: .leading, spacing: ZapSpacing.xs) {
                Text("Code")
                    .font(.caption)
                    .foregroundColor(ZapColors.textSecondary)

                TextField("123456", text: $authViewModel.otpCode)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .focused($isCodeFieldFocused)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, ZapSpacing.sm)
                    .padding(.horizontal, ZapSpacing.base)
                    .background(
                        RoundedRectangle(cornerRadius: ZapRadius.medium)
                            .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }

            if let error = authViewModel.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, ZapSpacing.base)
            }

            ZapButton(
                authViewModel.isVerifyingCode ? "Verifying..." : "Login",
                isLoading: authViewModel.isVerifyingCode,
                isDisabled: authViewModel.otpCode.count != 6
            ) {
                Task {
                    await authViewModel.verifyCode()
                }
            }
            .padding(.top, ZapSpacing.base)

            Button("Back") {
                authViewModel.reset()
            }
            .padding(.top, ZapSpacing.sm)

            Spacer()
        }
        .padding(.horizontal, ZapSpacing.xl)
        .background(ZapColors.background.ignoresSafeArea())
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isCodeFieldFocused = true
            }
        }
    }
}
