import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var walletViewModel: WalletViewModel
    @State private var selectedTab = 0
    @State private var showNavLabels = false
    let onResetWallet: () -> Void

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(
                walletViewModel: walletViewModel,
                showNavLabels: showNavLabels
            )
            .tag(0)
            .tabItem {
                Image(systemName: "house.fill")
                if showNavLabels {
                    Text("Home")
                }
            }

            SettingsView(onResetWallet: onResetWallet)
                .tag(1)
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    if showNavLabels {
                        Text("Settings")
                    }
                }
        }
        .tint(ZapColors.primary)
        .task {
            await walletViewModel.loadWalletIfNeeded()
        }
        .task(id: selectedTab) {
            guard selectedTab == 0 else { return }
            showNavLabels = true
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            showNavLabels = false
        }
    }
}
