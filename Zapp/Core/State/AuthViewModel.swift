import Foundation
import Combine

enum AuthStep {
    case email
    case otp
    case authenticated
}

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var otpCode: String = ""
    @Published var isSendingCode: Bool = false
    @Published var isVerifyingCode: Bool = false
    @Published var errorMessage: String?
    @Published var step: AuthStep = .email
    @Published var token: AuthToken?

    private let authService: AuthServicing

    init(authService: AuthServicing) {
        self.authService = authService
    }

    func sendCode() async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Email is required."
            return
        }

        isSendingCode = true
        errorMessage = nil

        do {
            try await authService.sendCode(to: trimmed)
            step = .otp
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        isSendingCode = false
    }

    func verifyCode() async {
        guard otpCode.count == 6 else {
            errorMessage = "Please enter a 6-digit code."
            return
        }

        isVerifyingCode = true
        errorMessage = nil

        do {
            let token = try await authService.verifyCode(email: email, code: otpCode)
            self.token = token
            step = .authenticated
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        isVerifyingCode = false
    }

    func reset() {
        email = ""
        otpCode = ""
        errorMessage = nil
        token = nil
        step = .email
    }
}
