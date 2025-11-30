import SwiftUI

struct EarnDepositTab: View {
    @ObservedObject var viewModel: EarnViewModel
    @State private var showBridgeConfirmation: Bool = false
    @State private var showAutoSendConfirmation: Bool = false
    @State private var isPoolSelectorExpanded: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: ZapSpacing.md) {
                    // Pool Selection (compact)
                    poolSelectionSection
                    
                    // Amount Input
                    amountInputSection
                    
                    // Compact Summary (only when amount > 0)
                    if viewModel.depositAmountDouble > 0 && viewModel.selectedPool != nil {
                        compactSummarySection
                    }
                }
                .padding(.horizontal, ZapSpacing.lg)
                .padding(.top, ZapSpacing.md)
            }
            
            // Fixed bottom action area
            bottomActionArea
                .padding(.horizontal, ZapSpacing.lg)
                .padding(.vertical, ZapSpacing.md)
                .background(Color(.systemBackground).shadow(color: .black.opacity(0.05), radius: 8, y: -4))
        }
        .sheet(isPresented: $showBridgeConfirmation) {
            BridgeConfirmationSheet(viewModel: viewModel, isPresented: $showBridgeConfirmation)
        }
        .sheet(isPresented: $showAutoSendConfirmation) {
            AutoSendConfirmationSheet(viewModel: viewModel, isPresented: $showAutoSendConfirmation)
        }
    }
    
    // MARK: - Pool Selection Section (Compact)
    
    private var poolSelectionSection: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.xs) {
            HStack {
                Text("Lending Pool")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ZapColors.textPrimary)
                
                Spacer()
                
                if viewModel.isLoadingPools {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
            
            PoolSelectionView(
                viewModel: viewModel,
                isExpanded: $isPoolSelectorExpanded
            )
        }
    }
    
    // MARK: - Amount Input Section (Compact)
    
    private var amountInputSection: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.xs) {
            Text("Amount")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(ZapColors.textPrimary)
            
            HStack {
                TextField("0.00", text: $viewModel.depositAmount)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundColor(ZapColors.textPrimary)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.leading)
                    .disabled(viewModel.depositTransactionSent)
                
                Text("ZEC")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(ZapColors.textSecondary)
            }
            .padding(ZapSpacing.sm)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(ZapRadius.medium)
            
            // Quick Amount Buttons (inline)
            HStack(spacing: ZapSpacing.xs) {
                ForEach([0.1, 0.5, 1.0, 5.0], id: \.self) { amount in
                    Button {
                        viewModel.depositAmount = String(format: "%.1f", amount)
                    } label: {
                        Text("\(amount, specifier: "%.1f")")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(ZapColors.textSecondary)
                            .padding(.horizontal, ZapSpacing.sm)
                            .padding(.vertical, 4)
                            .background(Color(.tertiarySystemBackground))
                            .cornerRadius(ZapRadius.small)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.depositTransactionSent)
                }
                
                Spacer()
                
                // Validation inline
                if let message = viewModel.depositValidationMessage {
                    Text(message)
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
        }
    }
    
    // MARK: - Compact Summary Section
    
    private var compactSummarySection: some View {
        VStack(spacing: ZapSpacing.xs) {
            if let pool = viewModel.selectedPool {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("You'll receive")
                            .font(.caption)
                            .foregroundColor(ZapColors.textSecondary)
                        Text(String(format: "~%.4f %@", viewModel.estimatedAmount, viewModel.receiveAssetSymbol))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(pool.formattedApy)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        Text("APY")
                            .font(.caption2)
                            .foregroundColor(ZapColors.textSecondary)
                    }
                }
                
                // Fee info inline
                HStack(spacing: ZapSpacing.sm) {
                    Text("Fee: \(viewModel.formattedBridgeFeePercent)")
                        .font(.caption2)
                        .foregroundColor(ZapColors.textSecondary)
                    
                    Text("•")
                        .foregroundColor(ZapColors.textSecondary)
                    
                    Text("Est. ~\(viewModel.bridgeDepositInfo?.estimatedArrivalMinutes ?? 10) min")
                        .font(.caption2)
                        .foregroundColor(ZapColors.textSecondary)
                }
            }
        }
        .padding(ZapSpacing.sm)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(ZapRadius.small)
    }
    
    // MARK: - Bottom Action Area (Fixed)
    
    private var bottomActionArea: some View {
        VStack(spacing: ZapSpacing.sm) {
            // Error message (if any)
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
            
            // State: ZEC Sent Successfully
            if viewModel.depositTransactionSent || viewModel.pendingFinalization {
                successStateView
            }
            // State: Ready to send
            else if viewModel.bridgeDepositInfo != nil {
                readyToSendView
            }
            // State: Initial - prepare deposit
            else {
                prepareDepositView
            }
        }
    }
    
    // MARK: - Success State (After sending)
    
    private var successStateView: some View {
        VStack(spacing: ZapSpacing.sm) {
            // Success banner
            HStack(spacing: ZapSpacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("ZEC Sent Successfully!")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                    Text("Processing automatically...")
                        .font(.caption)
                        .foregroundColor(ZapColors.textSecondary)
                }
                
                Spacer()
                
                ProgressView()
                    .scaleEffect(0.8)
            }
            .padding(ZapSpacing.md)
            .background(Color.green.opacity(0.1))
            .cornerRadius(ZapRadius.medium)
            
            // View positions button
            Button {
                viewModel.currentTab = .positions
                viewModel.resetDepositFlow()
            } label: {
                HStack {
                    Image(systemName: "list.bullet.rectangle")
                    Text("View My Positions")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(ZapColors.primary)
                .frame(maxWidth: .infinity)
                .padding(ZapSpacing.sm)
                .background(ZapColors.primary.opacity(0.1))
                .cornerRadius(ZapRadius.medium)
            }
            
            // New deposit button
            Button("Start New Deposit") {
                viewModel.resetDepositFlow()
            }
            .font(.caption)
            .foregroundColor(ZapColors.textSecondary)
        }
    }
    
    // MARK: - Ready to Send State
    
    private var readyToSendView: some View {
        VStack(spacing: ZapSpacing.sm) {
            // Testnet indicator (compact)
            if viewModel.isTestnetDeposit {
                HStack(spacing: ZapSpacing.xs) {
                    Image(systemName: "testtube.2")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("Testnet Mode")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            // Main send button
            ZapButton(
                "Send \(String(format: "%.4f", viewModel.depositAmountDouble)) ZEC",
                isLoading: viewModel.isSendingDeposit,
                isDisabled: !viewModel.isWalletReady
            ) {
                showAutoSendConfirmation = true
            }
            
            // Wallet sync status
            if !viewModel.isWalletReady {
                HStack(spacing: ZapSpacing.xs) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Syncing wallet...")
                        .font(.caption)
                        .foregroundColor(ZapColors.textSecondary)
                }
            }
            
            // Cancel
            Button("Cancel") {
                viewModel.resetDepositFlow()
            }
            .font(.caption)
            .foregroundColor(ZapColors.textSecondary)
        }
    }
    
    // MARK: - Prepare Deposit State
    
    private var prepareDepositView: some View {
        VStack(spacing: ZapSpacing.xs) {
            // Pool selection hint
            if viewModel.selectedPool == nil && viewModel.depositAmountDouble > 0 {
                Text("Select a pool above to continue")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            // Main button
            ZapButton(
                viewModel.selectedPool != nil
                    ? "Deposit \(String(format: "%.4f", viewModel.depositAmountDouble)) ZEC"
                    : "Select Pool & Amount",
                isLoading: viewModel.isPreparingDeposit,
                isDisabled: !viewModel.canDeposit
            ) {
                Task {
                    await viewModel.prepareDeposit()
                }
            }
        }
    }
}

// MARK: - Bridge Confirmation Sheet

struct BridgeConfirmationSheet: View {
    @ObservedObject var viewModel: EarnViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: ZapSpacing.xl) {
                // Icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                    .padding(.top, ZapSpacing.xl)
                
                // Title
                Text("Confirm Deposit")
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Info
                VStack(spacing: ZapSpacing.sm) {
                    Text("Have you sent \(viewModel.depositAmountDouble) ZEC to the bridge address?")
                        .font(.body)
                        .foregroundColor(ZapColors.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    // Show selected pool info
                    if let pool = viewModel.selectedPool {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Depositing to")
                                    .font(.caption)
                                    .foregroundColor(ZapColors.textSecondary)
                                Text("\(pool.displayName)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(pool.formattedApy)
                                    .font(.headline)
                                    .foregroundColor(.green)
                                Text("APY")
                                    .font(.caption)
                                    .foregroundColor(ZapColors.textSecondary)
                            }
                        }
                        .padding(ZapSpacing.md)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(ZapRadius.medium)
                    }
                    
                    Text("Once confirmed, we'll track your deposit and start earning once it arrives on NEAR via RHEA Finance.")
                        .lineLimit(nil)
                        .font(.caption)
                        .foregroundColor(ZapColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, ZapSpacing.lg)
                
                Spacer()
                
                // Error
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                // Buttons
                VStack(spacing: ZapSpacing.sm) {
                    ZapButton("Yes, I've Sent It", isLoading: viewModel.isLoading) {
                        Task {
                            await viewModel.createPosition()
                            isPresented = false
                        }
                    }
                    
                    Button("Not Yet") {
                        isPresented = false
                    }
                    .font(.body)
                    .foregroundColor(ZapColors.textSecondary)
                }
            }
            .padding(.horizontal, ZapSpacing.xl)
            .padding(.bottom, ZapSpacing.xl)
            .navigationTitle("Confirm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ZapColors.textSecondary)
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Auto Send Confirmation Sheet

struct AutoSendConfirmationSheet: View {
    @ObservedObject var viewModel: EarnViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: ZapSpacing.xl) {
                // Icon
                ZStack {
                    Circle()
                        .fill(ZapColors.primary.opacity(0.2))
                        .frame(width: 80, height: 80)
                    Image(systemName: "paperplane.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(ZapColors.primary)
                }
                .padding(.top, ZapSpacing.xl)
                
                // Title
                Text("Confirm Auto-Send")
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Summary Card
                VStack(spacing: ZapSpacing.sm) {
                    summaryRow(label: "Amount", value: String(format: "%.6f ZEC", viewModel.depositAmountDouble))
                    
                    if let pool = viewModel.selectedPool {
                        summaryRow(label: "Pool", value: pool.displayName)
                        summaryRow(label: "Expected APY", value: pool.formattedApy, valueColor: .green)
                    }
                    
                    if let bridgeInfo = viewModel.bridgeDepositInfo {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sending to Bridge Address:")
                                .font(.caption)
                                .foregroundColor(ZapColors.textSecondary)
                            Text(bridgeInfo.bridgeAddress)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(ZapColors.textPrimary)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(ZapSpacing.md)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(ZapRadius.medium)
                .padding(.horizontal, ZapSpacing.lg)
                
                // Warning - different for testnet vs mainnet
                if viewModel.isTestnetDeposit {
                    VStack(spacing: ZapSpacing.sm) {
                        HStack(spacing: ZapSpacing.sm) {
                            Image(systemName: "testtube.2")
                                .foregroundColor(.orange)
                            Text("TESTNET MODE")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                        }
                        Text("This will send TAZ (testnet ZEC) to a simulated bridge address. The bridge is simulated for development testing.")
                            .font(.caption)
                            .foregroundColor(ZapColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(ZapSpacing.sm)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(ZapRadius.small)
                    .padding(.horizontal, ZapSpacing.lg)
                } else {
                    HStack(spacing: ZapSpacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("This will send ZEC from your wallet. This action cannot be undone.")
                            .font(.caption)
                            .foregroundColor(ZapColors.textSecondary)
                    }
                    .padding(ZapSpacing.sm)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(ZapRadius.small)
                    .padding(.horizontal, ZapSpacing.lg)
                }
                
                Spacer()
                
                // Error
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, ZapSpacing.lg)
                }
                
                // Buttons
                VStack(spacing: ZapSpacing.sm) {
                    ZapButton(
                        viewModel.isTestnetDeposit 
                            ? "Send \(viewModel.depositAmountDouble) TAZ"
                            : "Send \(viewModel.depositAmountDouble) ZEC",
                        isLoading: viewModel.isSendingDeposit
                    ) {
                        Task {
                            await viewModel.sendDepositToBridge()
                            if viewModel.depositTransactionSent {
                                isPresented = false
                            }
                        }
                    }
                    
                    Button("Cancel") {
                        isPresented = false
                    }
                    .font(.body)
                    .foregroundColor(ZapColors.textSecondary)
                }
            }
            .padding(.horizontal, ZapSpacing.xl)
            .padding(.bottom, ZapSpacing.xl)
            .navigationTitle(viewModel.isTestnetDeposit ? "Confirm Testnet Send" : "Confirm Send")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ZapColors.textSecondary)
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
    
    private func summaryRow(label: String, value: String, valueColor: Color = ZapColors.textPrimary) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(ZapColors.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(valueColor)
        }
    }
}

#Preview {
    EarnDepositTab(
        viewModel: EarnViewModel(
            apiService: EarnAPIService.shared,
            zcashWalletAddress: "zs1test"
        )
    )
}
