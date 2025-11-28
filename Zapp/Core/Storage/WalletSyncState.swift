import Foundation

struct WalletSyncState {
    let statusText: String
    let progress: Double
    let isSynced: Bool
    let areFundsSpendable: Bool

    static let initial = WalletSyncState(statusText: "Unprepared", progress: 0.0, isSynced: false, areFundsSpendable: false)
}
