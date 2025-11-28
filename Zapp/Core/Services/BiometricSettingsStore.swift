import Foundation

/// A simple UserDefaults wrapper for storing biometric authentication preferences.
/// This does NOT store any biometric data - only user preferences about whether
/// to use biometric authentication for certain actions.
final class BiometricSettingsStore {
    
    // MARK: - Keys
    
    private enum Keys {
        static let isBiometricEnabled = "biometric_enabled"
        static let hasPromptedForBiometric = "biometric_setup_prompted"
    }
    
    // MARK: - Singleton
    
    static let shared = BiometricSettingsStore()
    
    private let defaults: UserDefaults
    
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }
    
    // MARK: - Properties
    
    /// Whether biometric authentication is enabled for sensitive actions.
    /// Default is `false` until user explicitly enables it.
    var isBiometricEnabled: Bool {
        get { defaults.bool(forKey: Keys.isBiometricEnabled) }
        set { defaults.set(newValue, forKey: Keys.isBiometricEnabled) }
    }
    
    /// Whether the user has been prompted to set up biometric authentication.
    /// This is used to show the setup prompt only once after wallet creation.
    var hasPromptedForBiometric: Bool {
        get { defaults.bool(forKey: Keys.hasPromptedForBiometric) }
        set { defaults.set(newValue, forKey: Keys.hasPromptedForBiometric) }
    }
    
    // MARK: - Methods
    
    /// Checks if biometric authentication should be required for sensitive actions.
    /// Returns `true` only if:
    /// 1. User has enabled biometric in settings
    /// 2. Biometric is available on the device
    func shouldRequireBiometric() -> Bool {
        return isBiometricEnabled && BiometricAuthService.shared.isBiometricAvailable()
    }
    
    /// Resets all biometric settings. Used when wallet is reset.
    func reset() {
        isBiometricEnabled = false
        hasPromptedForBiometric = false
    }
}
