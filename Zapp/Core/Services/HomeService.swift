import Foundation

struct HomeSummary {
    let totalBalance: Decimal
    let change24h: Decimal
}

protocol HomeServicing {
    func fetchSummary() async throws -> HomeSummary
}

enum HomeError: Error, LocalizedError {
    case failed

    var errorDescription: String? {
        switch self {
        case .failed:
            return "Unable to load home data."
        }
    }
}

final class HomeServiceStub: HomeServicing {
    func fetchSummary() async throws -> HomeSummary {
        try await Task.sleep(nanoseconds: 200_000_000)
        return HomeSummary(totalBalance: 1234.56, change24h: 2.34)
    }
}
