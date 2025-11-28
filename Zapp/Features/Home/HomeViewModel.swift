import Foundation
import Combine

final class HomeViewModel: ObservableObject {
    @Published var totalBalance: Decimal?
    @Published var change24h: Decimal?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let service: HomeServicing

    init(service: HomeServicing) {
        self.service = service
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil

        do {
            let summary = try await service.fetchSummary()
            totalBalance = summary.totalBalance
            change24h = summary.change24h
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        isLoading = false
    }
}
