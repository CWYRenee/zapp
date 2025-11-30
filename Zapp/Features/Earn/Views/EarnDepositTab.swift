import SwiftUI

struct EarnDepositTab: View {
    @ObservedObject var viewModel: EarnViewModel
    @State private var showBridgeConfirmation: Bool = false
    @State private var showAutoSendConfirmation: Bool = false
    @State private var isPoolSelectorExpanded: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ZapSpacing.xl) {
                // Pool Selection Section (NEW)
                poolSelectionSection
                
                // Amount Input Section
                amountInputSection
                
                // Deposit Summary
                if viewModel.depositAmountDouble > 0 && viewModel.selectedPool != nil {
                    depositSummarySection
                }
                
                // Bridge Info (if prepared)
                if let bridgeInfo = viewModel.bridgeDepositInfo {
                    bridgeInfoSection(bridgeInfo)
                }
                
                // Action Button
                actionButtonSection
                
                // Info Cards
                infoCardsSection
                
                Spacer(minLength: ZapSpacing.xl)
            }
            .padding(.horizontal, ZapSpacing.xl)
            .padding(.top, ZapSpacing.lg)
        }
        .sheet(isPresented: $showBridgeConfirmation) {
            BridgeConfirmationSheet(viewModel: viewModel, isPresented: $showBridgeConfirmation)
        }
        .sheet(isPresented: $showAutoSendConfirmation) {
            AutoSendConfirmationSheet(viewModel: viewModel, isPresented: $showAutoSendConfirmation)
        }
    }
    
    // MARK: - Pool Selection Section
    
    private var poolSelectionSection: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.sm) {
            HStack {
                Text("Select Lending Pool")
                    .font(.headline)
                    .foregroundColor(ZapColors.textPrimary)
                
                Spacer()
                
                if viewModel.isLoadingPools {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            
            Text("Choose where to lend your ZEC and earn yield on RHEA Finance")
                .font(.caption)
                .foregroundColor(ZapColors.textSecondary)
            
            PoolSelectionView(
                viewModel: viewModel,
                isExpanded: $isPoolSelectorExpanded
            )
        }
    }
    
    // MARK: - Amount Input Section
    
    private var amountInputSection: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.sm) {
            Text("Deposit Amount")
                .font(.headline)
                .foregroundColor(ZapColors.textPrimary)
            
            HStack {
                TextField("0.00", text: $viewModel.depositAmount)
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .foregroundColor(ZapColors.textPrimary)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.leading)
                
                Text("ZEC")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(ZapColors.textSecondary)
            }
            .padding(ZapSpacing.md)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(ZapRadius.medium)
            
            // Validation Message
            if let message = viewModel.depositValidationMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            // Quick Amount Buttons
            HStack(spacing: ZapSpacing.sm) {
                ForEach([0.1, 0.5, 1.0, 5.0], id: \.self) { amount in
                    Button {
                        viewModel.depositAmount = String(format: "%.1f", amount)
                    } label: {
                        Text("\(amount, specifier: "%.1f")")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(ZapColors.textSecondary)
                            .padding(.horizontal, ZapSpacing.sm)
                            .padding(.vertical, ZapSpacing.xs)
                            .background(Color(.tertiarySystemBackground))
                            .cornerRadius(ZapRadius.small)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Deposit Summary Section
    
    private var depositSummarySection: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.sm) {
            Text("Deposit Summary")
                .font(.headline)
                .foregroundColor(ZapColors.textPrimary)
            
            VStack(spacing: ZapSpacing.sm) {
                // Selected pool info
                if let pool = viewModel.selectedPool {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Lending to")
                                .font(.caption)
                                .foregroundColor(ZapColors.textSecondary)
                            Text("\(pool.displayName) on RHEA Finance")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(ZapColors.textPrimary)
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
                    .padding(ZapSpacing.sm)
                    .background(ZapColors.primary.opacity(0.1))
                    .cornerRadius(ZapRadius.small)
                }
                
                Divider()
                
                // You Send
                summaryRow(label: "You Send", value: String(format: "%.6f ZEC", viewModel.depositAmountDouble))
                
                // Bridge Fee (dynamic)
                summaryRow(
                    label: "Bridge Fee (\(viewModel.formattedBridgeFeePercent))",
                    value: String(format: "-%.6f ZEC", viewModel.bridgeFeeAmount)
                )
                
                // Pool Fee (if applicable)
                if let pool = viewModel.selectedPool, pool.fee > 0 {
                    summaryRow(
                        label: "Pool Fee (\(pool.formattedFee))",
                        value: "Included in APY",
                        valueColor: ZapColors.textSecondary
                    )
                }
                
                Divider()
                
                // You Receive - based on selected pool
                if let pool = viewModel.selectedPool {
                    summaryRow(
                        label: "You Receive",
                        value: String(format: "%.6f %@", viewModel.estimatedAmount, viewModel.receiveAssetSymbol),
                        isBold: true
                    )
                    
                    // Show pool token breakdown
                    Text("Your ZEC will be converted to \(pool.tokenSymbols.joined(separator: " + ")) liquidity")
                        .font(.caption2)
                        .foregroundColor(ZapColors.textSecondary)
                        .padding(.top, 2)
                }
                
                Divider()
                
                // Expected APY from pool
                summaryRow(
                    label: "Expected APY",
                    value: viewModel.formattedCurrentApy,
                    valueColor: .green
                )
                
                // Estimated earnings in 1 year based on pool APY
                let yearlyEarnings = viewModel.estimatedAmount * (viewModel.currentApy / 100)
                summaryRow(
                    label: "Est. Yearly Earnings",
                    value: String(format: "+%.6f ZEC", yearlyEarnings),
                    valueColor: .green
                )
            }
            .padding(ZapSpacing.md)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(ZapRadius.medium)
        }
    }
    
    private func summaryRow(
        label: String,
        value: String,
        valueColor: Color = ZapColors.textPrimary,
        isBold: Bool = false
    ) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(ZapColors.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(isBold ? .semibold : .regular)
                .foregroundColor(valueColor)
        }
    }
    
    // MARK: - Bridge Info Section
    
    private func bridgeInfoSection(_ bridgeInfo: BridgeDepositInfo) -> some View {
        VStack(alignment: .leading, spacing: ZapSpacing.sm) {
            // Simulation Warning Banner
            if bridgeInfo.isSimulated ?? true {
                HStack(spacing: ZapSpacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Testnet Simulation")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                        Text("This is a simulated address for testing. Do NOT send real ZEC.")
                            .font(.caption2)
                            .foregroundColor(ZapColors.textSecondary)
                    }
                }
                .padding(ZapSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.15))
                .cornerRadius(ZapRadius.small)
            } else {
                // Live address indicator
                HStack(spacing: ZapSpacing.sm) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Live Bridge Address")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                        Text("From \(bridgeInfo.sourceDescription)")
                            .font(.caption2)
                            .foregroundColor(ZapColors.textSecondary)
                    }
                }
                .padding(ZapSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.15))
                .cornerRadius(ZapRadius.small)
            }
            
            HStack {
                Text("Bridge Address")
                    .font(.headline)
                    .foregroundColor(ZapColors.textPrimary)
                
                Spacer()
                
                Button {
                    UIPasteboard.general.string = bridgeInfo.bridgeAddress
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy")
                    }
                    .font(.caption)
                    .foregroundColor(ZapColors.primary)
                }
            }
            
            VStack(alignment: .leading, spacing: ZapSpacing.sm) {
                // Bridge Address
                Text(bridgeInfo.bridgeAddress)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(ZapColors.textPrimary)
                    .padding(ZapSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(ZapRadius.small)
                
                // Instructions - different for simulated vs live
                if bridgeInfo.isSimulated ?? true {
                    HStack(spacing: ZapSpacing.sm) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.orange)
                        Text("In testnet mode. Bridge flow is simulated for development.")
                            .font(.caption)
                            .foregroundColor(ZapColors.textSecondary)
                    }
                } else {
                    HStack(spacing: ZapSpacing.sm) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("Send exactly \(viewModel.depositAmountDouble) ZEC to this address to start earning")
                            .font(.caption)
                            .foregroundColor(ZapColors.textSecondary)
                    }
                }
                
                // Estimated arrival
                HStack(spacing: ZapSpacing.sm) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.orange)
                    Text("Estimated arrival: ~\(bridgeInfo.estimatedArrivalMinutes) minutes")
                        .font(.caption)
                        .foregroundColor(ZapColors.textSecondary)
                }
            }
            .padding(ZapSpacing.md)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(ZapRadius.medium)
        }
    }
    
    // MARK: - Action Button Section
    
    private var actionButtonSection: some View {
        VStack(spacing: ZapSpacing.sm) {
            if viewModel.bridgeDepositInfo == nil {
                // Show pool selection prompt if no pool selected
                if viewModel.selectedPool == nil && viewModel.depositAmountDouble > 0 {
                    HStack(spacing: ZapSpacing.xs) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                        Text("Please select a lending pool above")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(ZapSpacing.sm)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(ZapRadius.small)
                }
                
                // Prepare deposit button
                ZapButton(
                    viewModel.selectedPool != nil 
                        ? "Deposit to \(viewModel.selectedPool!.displayName)"
                        : "Prepare Deposit",
                    isLoading: viewModel.isPreparingDeposit,
                    isDisabled: !viewModel.canDeposit
                ) {
                    Task {
                        await viewModel.prepareDeposit()
                    }
                }
            } else {
                // Bridge info is available - show send options
                if let bridgeInfo = viewModel.bridgeDepositInfo {
                    // Auto-send button (works for both testnet and mainnet)
                    if viewModel.isWalletReady {
                        // Testnet indicator
                        if viewModel.isTestnetDeposit {
                            HStack(spacing: ZapSpacing.xs) {
                                Image(systemName: "testtube.2")
                                    .foregroundColor(.orange)
                                Text("Testnet Mode - Sending to simulated bridge")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            .padding(ZapSpacing.sm)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(ZapRadius.small)
                        }
                        
                        ZapButton(
                            "Send \(viewModel.depositAmountDouble) ZEC Now",
                            isLoading: viewModel.isSendingDeposit,
                            isDisabled: false
                        ) {
                            showAutoSendConfirmation = true
                        }
                        
                        Text(viewModel.isTestnetDeposit 
                            ? "Your TAZ will be sent to the testnet bridge address"
                            : "Your ZEC will be sent automatically to the bridge")
                            .font(.caption)
                            .foregroundColor(ZapColors.textSecondary)
                            .multilineTextAlignment(.center)
                        
                        Divider()
                            .padding(.vertical, ZapSpacing.xs)
                        
                        // Manual option
                        Button("I'll send manually instead") {
                            showBridgeConfirmation = true
                        }
                        .font(.caption)
                        .foregroundColor(ZapColors.primary)
                    } else {
                        // Wallet not ready
                        HStack(spacing: ZapSpacing.xs) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Waiting for wallet to sync...")
                                .font(.caption)
                                .foregroundColor(ZapColors.textSecondary)
                        }
                        
                        // Manual send flow while waiting
                        ZapButton("I've Sent the ZEC Manually", isLoading: viewModel.isLoading) {
                            showBridgeConfirmation = true
                        }
                    }
                }
                
                // Cancel button
                Button("Cancel") {
                    viewModel.resetDepositFlow()
                }
                .font(.body)
                .foregroundColor(ZapColors.textSecondary)
            }
            
            // Success message
            if viewModel.depositTransactionSent && !viewModel.pendingFinalization {
                HStack(spacing: ZapSpacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Transaction sent! Your deposit is being processed.")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .padding(ZapSpacing.sm)
                .background(Color.green.opacity(0.1))
                .cornerRadius(ZapRadius.small)
            }
            
            // Finalization Section (for future live bridges)
            if viewModel.pendingFinalization {
                finalizationSection
            }
            
            // Error message
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Finalization Section (reserved)
    
    private var finalizationSection: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.md) {
            // Header
            HStack(spacing: ZapSpacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("ZEC Sent Successfully!")
                        .font(.headline)
                        .foregroundColor(ZapColors.textPrimary)
                    Text("Complete the finalization to mint nZEC on NEAR")
                        .font(.caption)
                        .foregroundColor(ZapColors.textSecondary)
                }
            }
            
            // Instructions
            VStack(alignment: .leading, spacing: ZapSpacing.sm) {
                Text("Final Step: Enter Transaction Details")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(ZapColors.textPrimary)
                
                Text("Wait for your Zcash transaction to have at least 3 confirmations, then enter the details below.")
                    .font(.caption)
                    .foregroundColor(ZapColors.textSecondary)
            }
            
            // Transaction Hash Input
            VStack(alignment: .leading, spacing: ZapSpacing.xs) {
                Text("Zcash Transaction Hash")
                    .font(.caption)
                    .foregroundColor(ZapColors.textSecondary)
                
                TextField("Enter transaction hash", text: $viewModel.finalizationTxHash)
                    .font(.system(.caption, design: .monospaced))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            
            // Vout Input
            VStack(alignment: .leading, spacing: ZapSpacing.xs) {
                Text("Output Index (vout)")
                    .font(.caption)
                    .foregroundColor(ZapColors.textSecondary)
                
                HStack {
                    Picker("Output Index", selection: $viewModel.finalizationVout) {
                        Text("0").tag(0)
                        Text("1").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 100)
                    
                    Spacer()
                    
                    Text("Usually 0 for standard transactions")
                        .font(.caption2)
                        .foregroundColor(ZapColors.textSecondary)
                }
            }
            
            // Finalize Button
            ZapButton(
                "Finalize Deposit",
                isLoading: viewModel.isFinalizingDeposit,
                isDisabled: viewModel.finalizationTxHash.isEmpty
            ) {
                Task {
                    await viewModel.finalizeDeposit()
                }
            }
            
            // Success Result
            if let result = viewModel.finalizationResult, result.success {
                VStack(alignment: .leading, spacing: ZapSpacing.xs) {
                    HStack(spacing: ZapSpacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Deposit Finalized!")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    
                    if let nZec = result.nZecAmount {
                        Text("Received: \(nZec) nZEC")
                            .font(.caption)
                            .foregroundColor(ZapColors.textSecondary)
                    }
                    
                    if let explorerUrl = result.explorerUrl, let url = URL(string: explorerUrl) {
                        Link("View on NEAR Explorer →", destination: url)
                            .font(.caption)
                            .foregroundColor(ZapColors.primary)
                    }
                }
                .padding(ZapSpacing.sm)
                .background(Color.green.opacity(0.1))
                .cornerRadius(ZapRadius.small)
            }
            
            // Cancel option
            Button("Cancel and Start Over") {
                viewModel.resetDepositFlow()
            }
            .font(.caption)
            .foregroundColor(ZapColors.textSecondary)
        }
        .padding(ZapSpacing.md)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(ZapRadius.medium)
    }
    
    // MARK: - Info Cards Section
    
    private var infoCardsSection: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.sm) {
            Text("How It Works")
                .font(.headline)
                .foregroundColor(ZapColors.textPrimary)
            
            VStack(spacing: ZapSpacing.sm) {
                infoCard(
                    step: "1",
                    title: "Select a Lending Pool",
                    description: "Choose from available liquidity pools on RHEA Finance. Higher APY pools may have more volatility.",
                    icon: "list.bullet.circle.fill"
                )
                
                infoCard(
                    step: "2",
                    title: "Bridge ZEC to NEAR",
                    description: "Send your ZEC to the bridge address. It will be wrapped and bridged to NEAR automatically.",
                    icon: "arrow.up.circle.fill"
                )
                
                infoCard(
                    step: "3",
                    title: "Earn Yield",
                    description: "Your wrapped ZEC is deposited into the selected pool to earn yield from trading fees and incentives.",
                    icon: "chart.line.uptrend.xyaxis.circle.fill"
                )
                
                infoCard(
                    step: "4",
                    title: "Withdraw Anytime",
                    description: "Withdraw your ZEC plus earnings back to your shielded wallet whenever you want.",
                    icon: "arrow.down.circle.fill"
                )
            }
        }
    }
    
    private func infoCard(step: String, title: String, description: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: ZapSpacing.md) {
            ZStack {
                Circle()
                    .fill(ZapColors.primary.opacity(0.2))
                    .frame(width: 32, height: 32)
                Text(step)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(ZapColors.primary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ZapColors.textPrimary)
                Text(description)
                    .font(.caption)
                    .foregroundColor(ZapColors.textSecondary)
            }
            
            Spacer()
        }
        .padding(ZapSpacing.sm)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(ZapRadius.small)
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
        .presentationDetents([.medium])
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
        .presentationDetents([.medium, .large])
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
