import Foundation
import Combine
import ZcashLightClientKit

@MainActor
final class TransactionListViewModel: ObservableObject {
    @Published var zapOrders: [ZapOrderDTO] = []
    @Published var onChainRows: [TransactionRow] = []
    @Published var isLoadingOrders: Bool = false
    @Published var isLoadingTransactions: Bool = false
    @Published var errorMessage: String?
    @Published var selectedFilter: ActivityFilter = .all
    
    private let zapOrderService = ZapOrderService()
    private let walletViewModel: WalletViewModel
    private var isPollingOrders: Bool = true
    private var currentPage: Int = 0
    private var hasMorePages: Bool = true
    
    enum ActivityFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case zapOrders = "Zapp Orders"
        case onChain = "On-chain"
        
        var id: String { rawValue }
    }
    
    struct TransactionRow: Identifiable, Equatable {
        let id: Data
        let overview: ZcashTransaction.Overview
        let title: String
        let detail: String
        let amountText: String
        let isOutgoing: Bool
    }
    
    init(walletViewModel: WalletViewModel) {
        self.walletViewModel = walletViewModel
    }
    
    func loadInitialData() async {
        await loadZapOrders()
        await loadTransactions(page: 0, reset: true)
        await startPollingOrders()
    }
    
    func refresh() async {
        await loadZapOrders()
        await loadTransactions(page: 0, reset: true)
    }
    
    func stopPolling() {
        isPollingOrders = false
    }
    
    private func startPollingOrders() async {
        await walletViewModel.loadWalletIfNeeded()
        
        guard let walletInfo = walletViewModel.walletInfo else {
            return
        }
        
        let address = walletInfo.address
        
        while isPollingOrders && !Task.isCancelled {
            await fetchZapOrders(for: address)
            try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
        }
    }
    
    private func loadZapOrders() async {
        await walletViewModel.loadWalletIfNeeded()
        
        guard let walletInfo = walletViewModel.walletInfo else {
            return
        }
        
        await fetchZapOrders(for: walletInfo.address)
    }
    
    private func fetchZapOrders(for walletAddress: String) async {
        if zapOrders.isEmpty {
            isLoadingOrders = true
        }
        
        do {
            let fetched = try await zapOrderService.listOrdersForUser(
                userWalletAddress: walletAddress,
                status: nil as String?
            )
            zapOrders = fetched
            errorMessage = nil
        } catch {
            if let localized = error as? LocalizedError, let description = localized.errorDescription {
                errorMessage = description
            } else {
                errorMessage = error.localizedDescription
            }
        }
        
        isLoadingOrders = false
    }
    
    private func loadTransactions(page: Int, reset: Bool) async {
        isLoadingTransactions = true
        if reset {
            onChainRows = []
            currentPage = 0
        }
        errorMessage = nil
        
        do {
            let result = try await walletViewModel.loadTransactionsPage(page: page)
            let newRows = result.items.map(makeRow(from:))
            
            if reset {
                onChainRows = newRows
            } else {
                onChainRows.append(contentsOf: newRows)
            }
            
            currentPage = page
            hasMorePages = (page + 1) < result.pageCount && !newRows.isEmpty
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        
        isLoadingTransactions = false
    }
    
    private func makeRow(from overview: ZcashTransaction.Overview) -> TransactionRow {
        let isOutgoing = overview.isSentTransaction
        let title: String
        if overview.minedHeight == nil {
            title = "Pending"
        } else if overview.isShielding {
            title = "Shielding"
        } else if isOutgoing {
            title = "Sent"
        } else {
            title = "Received"
        }
        
        let dateText: String
        if let blockTime = overview.blockTime {
            let date = Date(timeIntervalSince1970: blockTime)
            dateText = dateFormatter.string(from: date)
        } else {
            dateText = "No date"
        }
        
        let txIdShort = shortTxId(from: overview.rawID)
        let detail = "\(dateText) • \(txIdShort)"
        
        let value = overview.value
        let formatted = value.tazString(abs: true)
        let sign = value.amount >= 0 ? "+" : "-"
        let amountText = "\(sign)\(formatted) TAZ"
        
        return TransactionRow(
            id: overview.rawID,
            overview: overview,
            title: title,
            detail: detail,
            amountText: amountText,
            isOutgoing: isOutgoing
        )
    }
    
    private func shortTxId(from data: Data) -> String {
        let hex = data.map { String(format: "%02x", $0) }.joined()
        guard hex.count > 12 else { return hex }
        let prefix = hex.prefix(6)
        let suffix = hex.suffix(6)
        return "\(prefix)...\(suffix)"
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd, HH:mm"
        return formatter
    }()
}
