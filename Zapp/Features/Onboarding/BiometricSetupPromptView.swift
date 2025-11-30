import SwiftUI

/// A view shown after wallet setup to prompt the user to enable biometric authentication.
/// This provides a clear explanation of what biometric auth protects and gives the user
/// a choice to enable or skip.
struct BiometricSetupPromptView: View {
    let onComplete: () -> Void
    
    private let biometricService = BiometricAuthService.shared
    private let settingsStore = BiometricSettingsStore.shared
    
    @State private var isAuthenticating: Bool = false
    @State private var errorMessage: String?
    
    private var biometricType: BiometricAuthService.BiometricType {
        biometricService.biometricType()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(minHeight: 40, maxHeight: 80)
            
            // Header section with icon
            VStack(spacing: ZapSpacing.lg) {
                Image(systemName: biometricType.iconName)
                    .font(.system(size: 72))
                    .foregroundColor(ZapColors.primary)
                
                Text("Secure Your Wallet")
                    .font(ZapTypography.titleFont)
                    .foregroundColor(ZapColors.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, ZapSpacing.xl)
            
            Spacer()
                .frame(minHeight: 24, maxHeight: 40)
            
            // Explanation section
            VStack(alignment: .leading, spacing: ZapSpacing.lg) {
                Text("Enable \(biometricType.displayName) to add an extra layer of security for sensitive actions:")
                    .font(.subheadline)
                    .foregroundColor(ZapColors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                VStack(alignment: .leading, spacing: ZapSpacing.sm) {
                    securityFeatureRow(icon: "arrow.up.circle.fill", text: "Sending transactions")
                    securityFeatureRow(icon: "creditcard.fill", text: "Making payments")
                    securityFeatureRow(icon: "key.fill", text: "Viewing recovery phrase")
                }
                
                Text("Your biometric data stays on your device and is never stored by this app.")
                    .font(.caption)
                    .foregroundColor(ZapColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, ZapSpacing.sm)
            }
            .padding(ZapSpacing.lg)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(ZapRadius.large)
            .padding(.horizontal, ZapSpacing.xl)
            
            if let error = errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, ZapSpacing.xl)
                    .padding(.top, ZapSpacing.sm)
            }
            
            Spacer()
                .frame(minHeight: 32, maxHeight: 60)
            
            // Action buttons
            VStack(spacing: ZapSpacing.base) {
                ZapButton("Enable \(biometricType.displayName)", isLoading: isAuthenticating) {
                    enableBiometric()
                }
                
                Button {
                    skipBiometric()
                } label: {
                    Text("Skip for now")
                        .font(.body)
                        .foregroundColor(ZapColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, ZapSpacing.xl)
            
            Spacer()
                .frame(minHeight: 40)
        }
        .background(ZapColors.background.ignoresSafeArea())
    }
    
    // MARK: - Private Views
    
    private func securityFeatureRow(icon: String, text: String) -> some View {
        HStack(spacing: ZapSpacing.sm) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(ZapColors.primary)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(ZapColors.textPrimary)
        }
    }
    
    // MARK: - Actions
    
    private func enableBiometric() {
        isAuthenticating = true
        errorMessage = nil
        
        Task {
            do {
                // Perform a test authentication to ensure biometrics work
                let success = try await biometricService.authenticate(
                    reason: "Authenticate to enable \(biometricType.displayName) for your wallet"
                )
                
                if success {
                    settingsStore.isBiometricEnabled = true
                    settingsStore.hasPromptedForBiometric = true
                    isAuthenticating = false
                    onComplete()
                }
            } catch let error as BiometricAuthService.BiometricError {
                isAuthenticating = false
                
                switch error {
                case .userCancelled:
                    // User cancelled, don't show error - they can try again
                    break
                default:
                    errorMessage = error.errorDescription
                }
            } catch {
                isAuthenticating = false
                errorMessage = "Failed to enable biometric authentication."
            }
        }
    }
    
    private func skipBiometric() {
        settingsStore.isBiometricEnabled = false
        settingsStore.hasPromptedForBiometric = true
        onComplete()
    }
}

#Preview {
    BiometricSetupPromptView {
        print("Completed")
    }
}
