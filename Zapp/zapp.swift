import SwiftUI
import UIKit

@main
struct ZappApp: App {
    @StateObject private var walletViewModel = WalletViewModel(walletService: ZcashWalletService())
    @StateObject private var currencyStore = CurrencyStore()

    init() {
        UITabBarItem.appearance().imageInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }

    var body: some Scene {
        WindowGroup {
            RootNavigationView()
                .environmentObject(walletViewModel)
                .environmentObject(currencyStore)
        }
    }
}
