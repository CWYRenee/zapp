import Foundation
import LocalAuthentication

/// A service for handling biometric authentication (Face ID / Touch ID).
/// This service does NOT store any biometric data - it only uses the system's
/// LocalAuthentication framework to authenticate the user.
final class BiometricAuthService {
    
    // MARK: - Singleton
    
    static let shared = BiometricAuthService()
    
    private init() {}
    
    // MARK: - Biometric Type
    
    enum BiometricType {
        case none
        case faceID
        case touchID
        
        var displayName: String {
            switch self {
            case .none: return "Biometrics"
            case .faceID: return "Face ID"
            case .touchID: return "Touch ID"
            }
        }
        
        var iconName: String {
            switch self {
            case .none: return "lock.shield"
            case .faceID: return "faceid"
            case .touchID: return "touchid"
            }
        }
    }
    
    // MARK: - Error Types
    
    enum BiometricError: LocalizedError {
        case notAvailable
        case notEnrolled
        case authenticationFailed
        case userCancelled
        case userFallback
        case lockout
        case systemCancel
        case unknown(Error)
        
        var errorDescription: String? {
            switch self {
            case .notAvailable:
                return "Biometric authentication is not available on this device."
            case .notEnrolled:
                return "No biometric data is enrolled. Please set up Face ID or Touch ID in Settings."
            case .authenticationFailed:
                return "Authentication failed. Please try again."
            case .userCancelled:
                return "Authentication was cancelled."
            case .userFallback:
                return "User selected fallback authentication."
            case .lockout:
                return "Too many failed attempts. Please try again later or use your passcode."
            case .systemCancel:
                return "Authentication was cancelled by the system."
            case .unknown(let error):
                return error.localizedDescription
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Returns the type of biometric authentication available on this device.
    func biometricType() -> BiometricType {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        
        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        case .opticID:
            // For Vision Pro, treat as Face ID for simplicity
            return .faceID
        case .none:
            return .none
        @unknown default:
            return .none
        }
    }
    
    /// Checks if biometric authentication is available on this device.
    func isBiometricAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    /// Authenticates the user using biometrics.
    /// - Parameter reason: The reason displayed to the user for authentication.
    /// - Returns: `true` if authentication succeeded, throws an error otherwise.
    @MainActor
    func authenticate(reason: String) async throws -> Bool {
        let context = LAContext()
        var error: NSError?
        
        // Check if biometrics are available
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let laError = error {
                throw mapLAError(laError)
            }
            throw BiometricError.notAvailable
        }
        
        // Perform authentication
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            return success
        } catch {
            if let laError = error as? LAError {
                throw mapLAError(laError as NSError)
            }
            throw BiometricError.unknown(error)
        }
    }
    
    /// Authenticates for sending transactions.
    @MainActor
    func authenticateForTransaction() async throws -> Bool {
        let biometricName = biometricType().displayName
        return try await authenticate(reason: "Authenticate with \(biometricName) to confirm this transaction")
    }
    
    /// Authenticates for revealing sensitive information.
    @MainActor
    func authenticateForSensitiveData() async throws -> Bool {
        let biometricName = biometricType().displayName
        return try await authenticate(reason: "Authenticate with \(biometricName) to view your recovery phrase")
    }
    
    // MARK: - Private Methods
    
    private func mapLAError(_ error: NSError) -> BiometricError {
        let code = LAError.Code(rawValue: error.code) ?? .authenticationFailed
        
        switch code {
        case .biometryNotAvailable:
            return .notAvailable
        case .biometryNotEnrolled:
            return .notEnrolled
        case .authenticationFailed:
            return .authenticationFailed
        case .userCancel:
            return .userCancelled
        case .userFallback:
            return .userFallback
        case .biometryLockout:
            return .lockout
        case .systemCancel:
            return .systemCancel
        default:
            return .unknown(error)
        }
    }
}
