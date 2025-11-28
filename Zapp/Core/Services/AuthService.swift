import Foundation

struct AuthToken {
    let value: String
}

protocol AuthServicing {
    func sendCode(to email: String) async throws
    func verifyCode(email: String, code: String) async throws -> AuthToken
}

enum AuthError: Error, LocalizedError {
    case invalidEmail
    case invalidCode
    case networkFailure
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address."
        case .invalidCode:
            return "The code you entered is not valid."
        case .networkFailure:
            return "A network error occurred. Please try again."
        case .unknown:
            return "An unknown error occurred."
        }
    }
}

final class AuthService: AuthServicing {
    func sendCode(to email: String) async throws {
        try await Task.sleep(nanoseconds: 300_000_000)
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("@"), trimmed.contains(".") else {
            throw AuthError.invalidEmail
        }
    }

    func verifyCode(email: String, code: String) async throws -> AuthToken {
        try await Task.sleep(nanoseconds: 300_000_000)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            throw AuthError.invalidEmail
        }
        guard code.count == 6 else {
            throw AuthError.invalidCode
        }
        return AuthToken(value: UUID().uuidString)
    }
}
