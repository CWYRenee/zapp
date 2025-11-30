import SwiftUI

/// Main Earn view - Zcash earning via NEAR Intents + RHEA Finance
struct EarnView: View {
    @StateObject private var viewModel: EarnViewModel
    @EnvironmentObject private var walletViewModel: WalletViewModel
    
    init(zcashWalletAddress: String) {
        _viewModel = StateObject(
            wrappedValue: EarnViewModel(
                apiService: EarnAPIService.shared,
                zcashWalletAddress: zcashWalletAddress
            )
        )
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                ZapColors.background.ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.protocolInfo == nil {
                    loadingView
                } else {
                    mainContent
                }
            }
            .navigationTitle("Earn")
            .navigationBarTitleDisplayMode(.large)
            .task {
                // Inject WalletViewModel for auto-send capability
                viewModel.setWalletViewModel(walletViewModel)
                await viewModel.loadInitialData()
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: ZapSpacing.lg) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading RHEA Finance...")
                .font(.headline)
                .foregroundColor(ZapColors.textSecondary)
        }
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            // Protocol Header
            protocolHeader
            
            // Tab Picker
            tabPicker
            
            // Tab Content
            TabView(selection: $viewModel.currentTab) {
                EarnOverviewTab(viewModel: viewModel)
                    .tag(EarnViewModel.EarnTab.overview)
                
                EarnDepositTab(viewModel: viewModel)
                    .tag(EarnViewModel.EarnTab.deposit)
                
                EarnPositionsTab(viewModel: viewModel)
                    .tag(EarnViewModel.EarnTab.positions)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }
    
    // MARK: - Protocol Header
    
    private var protocolHeader: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.sm) {
            HStack(alignment: .center, spacing: ZapSpacing.md) {
                HStack(spacing: ZapSpacing.sm) {
                    ZStack {
                        Circle()
                            .fill(ZapColors.primary.opacity(0.15))
                        Image("rhea_finance_logo")
                            .resizable()
                            .scaledToFill()
                            .clipShape(Circle())
                    }
                    .frame(width: 44, height: 44)
                    
                    VStack(alignment: .leading, spacing: ZapSpacing.xs) {
                        Text("RHEA Finance")
                            .font(ZapTypography.titleFont)
                            .foregroundColor(ZapColors.textPrimary)
                    }
                }
                
                Spacer()
                
                // Current APY
                if let protocolInfo = viewModel.protocolInfo {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(protocolInfo.formattedApy)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(ZapColors.primary)
                        Text("APY")
                            .font(.caption)
                            .foregroundColor(ZapColors.textSecondary)
                    }
                }
            }
            
            if let health = viewModel.bridgeHealth {
                HStack(spacing: 4) {
                    Circle()
                        .fill(health.isOperational ? Color.green : Color.red)
                        .frame(width: 6, height: 6)
                    Text(health.isOperational ? "Bridge Active" : "Bridge Offline")
                        .font(.caption)
                        .foregroundColor(ZapColors.textSecondary)
                }
            }
        }
        .padding(.horizontal, ZapSpacing.xl)
        .padding(.vertical, ZapSpacing.md)
        .background(Color(.secondarySystemBackground))
    }
    
    private var tabPicker: some View {
        HStack(spacing: ZapSpacing.sm) {
            ForEach(EarnViewModel.EarnTab.allCases) { tab in
                Button {
                    withAnimation {
                        viewModel.currentTab = tab
                    }
                } label: {
                    HStack(spacing: ZapSpacing.xs) {
                        Image(systemName: tab.icon)
                            .font(.caption)
                        Text(tab.rawValue)
                            .font(.subheadline)
                            .fontWeight(viewModel.currentTab == tab ? .semibold : .regular)
                    }
                    .foregroundColor(viewModel.currentTab == tab ? .white : ZapColors.textSecondary)
                    .padding(.horizontal, ZapSpacing.md)
                    .padding(.vertical, ZapSpacing.sm)
                    .background(
                        viewModel.currentTab == tab
                            ? ZapColors.primary
                            : Color(.tertiarySystemBackground)
                    )
                    .cornerRadius(ZapRadius.small)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, ZapSpacing.xl)
        .padding(.vertical, ZapSpacing.sm)
    }
}

// MARK: - Preview

#Preview {
    EarnView(zcashWalletAddress: "zs1testaddress123")
}
