import SwiftUI

struct RootNavigationView: View {
    private let biometricService = BiometricAuthService.shared
    private let biometricSettings = BiometricSettingsStore.shared
    
    @State private var hasWallet: Bool = WalletSeedStore().loadSeed() != nil
    @State private var showBiometricSetup: Bool = false

    var body: some View {
        Group {
            if showBiometricSetup {
                BiometricSetupPromptView {
                    showBiometricSetup = false
                }
            } else if hasWallet {
                MainTabView(onResetWallet: {
                    // Reset biometric settings when wallet is reset
                    biometricSettings.reset()
                    hasWallet = false
                })
            } else {
                WalletOnboardingView {
                    hasWallet = true
                    // Check if we should prompt for biometric setup
                    checkBiometricSetup()
                }
            }
        }
    }
    
    /// Checks if biometric setup prompt should be shown after wallet creation.
    private func checkBiometricSetup() {
        // Only prompt if:
        // 1. User hasn't been prompted before
        // 2. Biometric is available on the device
        if !biometricSettings.hasPromptedForBiometric && biometricService.isBiometricAvailable() {
            showBiometricSetup = true
        }
    }
}
