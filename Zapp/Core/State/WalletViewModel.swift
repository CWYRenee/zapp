import Foundation
import Combine
import ZcashLightClientKit

@MainActor
final class WalletViewModel: ObservableObject {
    @Published var walletInfo: WalletInfo?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var totalZecBalanceText: String = ""
    @Published var spendableZecBalanceText: String = ""
    @Published var totalUsdBalance: Decimal?
    @Published var syncStatusText: String = WalletSyncState.initial.statusText
    @Published var syncProgress: Double = WalletSyncState.initial.progress
    @Published var isSynced: Bool = WalletSyncState.initial.isSynced
    @Published var areFundsSpendable: Bool = WalletSyncState.initial.areFundsSpendable
    @Published var isShieldingTransparentFunds: Bool = false

    private let walletService: WalletServicing
    private var cancellable: AnyCancellable?

    init(walletService: WalletServicing) {
        self.walletService = walletService
        self.cancellable = walletService.syncStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.syncStatusText = state.statusText
                self?.syncProgress = state.progress
                self?.isSynced = state.isSynced
                self?.areFundsSpendable = state.areFundsSpendable
            }
    }

    func loadWalletIfNeeded() async {
        if walletInfo != nil {
            return
        }

        await reloadWallet()
    }

    func reloadWallet() async {
        isLoading = true
        errorMessage = nil

        do {
            let info = try await walletService.initializeWalletIfNeeded()
            walletInfo = info
            totalZecBalanceText = format(zatoshi: info.totalBalance)
            spendableZecBalanceText = format(zatoshi: info.verifiedBalance)

            updateTotalUsdBalance(from: info.totalBalance)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        isLoading = false
    }

    func loadTransactionsPage(page: Int) async throws -> WalletTransactionsPage {
        try await walletService.loadTransactionsPage(page: page)
    }

    func loadMemos(for rawID: Data) async throws -> [Memo] {
        try await walletService.loadMemos(for: rawID)
    }

    func send(to address: String, amount: String, memo: String?) async throws -> Data {
        try await walletService.send(to: address, amount: amount, memo: memo)
    }

    func shieldTransparentFunds() async {
        guard !isShieldingTransparentFunds else { return }

        isShieldingTransparentFunds = true
        errorMessage = nil

        do {
            try await walletService.shieldTransparentFunds()
            await reloadWallet()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        isShieldingTransparentFunds = false
    }

    func resetWallet() async {
        isLoading = true
        errorMessage = nil

        do {
            try await walletService.resetWallet()
            walletInfo = nil
            totalZecBalanceText = ""
            spendableZecBalanceText = ""
            syncStatusText = WalletSyncState.initial.statusText
            syncProgress = WalletSyncState.initial.progress
            isSynced = WalletSyncState.initial.isSynced
            areFundsSpendable = WalletSyncState.initial.areFundsSpendable
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        isLoading = false
    }

    private func format(zatoshi: Zatoshi) -> String {
        let text = zatoshi.tazString()
        return "\(text) TAZ"
    }

    private func updateTotalUsdBalance(from total: Zatoshi) {
        let zecString = total.tazString(abs: true)
        guard let zecDecimal = Decimal(string: zecString) else {
            totalUsdBalance = nil
            return
        }

        Task.detached { [zecDecimal] in
            do {
                let price = try await SwapKitPriceService.shared.fetchZecUsdPrice()
                let usd = zecDecimal * Decimal(price)
                await MainActor.run {
                    self.totalUsdBalance = usd
                }
            } catch {
                await MainActor.run {
                    self.totalUsdBalance = nil
                }
            }
        }
    }

    var isReadyToSpend: Bool {
        isSynced || areFundsSpendable
    }
}
