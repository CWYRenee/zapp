import Foundation
import Combine

@MainActor
final class EarnViewModel: ObservableObject {
    // MARK: - Published Properties
    
    // UI State
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var currentTab: EarnTab = .overview
    
    // Protocol Info
    @Published var protocolInfo: LendingProtocolInfo?
    @Published var bridgeHealth: BridgeHealth?
    @Published var apyHistory: [ApyHistoryPoint] = []
    
    // Positions
    @Published var positions: [EarnPositionSummary] = []
    @Published var selectedPosition: EarnPositionSummary?
    @Published var positionEarningsHistory: [EarningsHistoryPoint] = []
    
    // User Stats
    @Published var userStats: UserEarnStats?
    
    // Lending Pools
    @Published var availablePools: [LendingPool] = []
    @Published var selectedPool: LendingPool?
    @Published var isLoadingPools: Bool = false
    
    // Deposit Flow
    @Published var depositAmount: String = ""
    @Published var bridgeDepositInfo: BridgeDepositInfo?
    @Published var isPreparingDeposit: Bool = false
    @Published var isSendingDeposit: Bool = false
    @Published var depositTransactionSent: Bool = false
    
    // Deposit Finalization (reserved for future live bridge integrations)
    @Published var pendingFinalization: Bool = false
    @Published var finalizationTxHash: String = ""
    @Published var finalizationVout: Int = 0
    @Published var isFinalizingDeposit: Bool = false
    @Published var finalizationResult: FinalizeDepositResult?
    @Published var createdPositionId: String?
    
    // Withdrawal Flow
    @Published var isWithdrawing: Bool = false
    @Published var withdrawToAddress: String = ""
    
    // MARK: - Dependencies
    
    private let apiService: EarnAPIService
    private let zcashWalletAddress: String
    private weak var walletViewModel: WalletViewModel?
    
    // MARK: - Initialization
    
    init(
        apiService: EarnAPIService,
        zcashWalletAddress: String,
        walletViewModel: WalletViewModel? = nil
    ) {
        self.apiService = apiService
        self.zcashWalletAddress = zcashWalletAddress
        self.walletViewModel = walletViewModel
    }
    
    /// Set the wallet view model (for dependency injection after init)
    func setWalletViewModel(_ walletViewModel: WalletViewModel) {
        self.walletViewModel = walletViewModel
    }
    
    /// Check if wallet is ready for sending
    var isWalletReady: Bool {
        walletViewModel?.isReadyToSpend ?? false
    }
    
    /// Check if auto-send is available (wallet connected)
    var canAutoSend: Bool {
        guard bridgeDepositInfo != nil else { return false }
        return isWalletReady
    }
    
    /// Check if the current deposit is to a simulated/testnet address
    var isTestnetDeposit: Bool {
        bridgeDepositInfo?.isSimulated ?? true
    }
    
    // MARK: - Tabs
    
    enum EarnTab: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case deposit = "Deposit"
        case positions = "Positions"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .overview: return "chart.line.uptrend.xyaxis"
            case .deposit: return "arrow.down.circle"
            case .positions: return "list.bullet"
            }
        }
    }
    
    // MARK: - Initial Load
    
    func loadInitialData() async {
        isLoading = true
        errorMessage = nil
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadProtocolInfo() }
            group.addTask { await self.loadBridgeHealth() }
            group.addTask { await self.loadApyHistory() }
            group.addTask { await self.loadPositions() }
            group.addTask { await self.loadUserStats() }
            group.addTask { await self.loadLendingPools() }
        }
        
        isLoading = false
    }
    
    func refresh() async {
        await loadInitialData()
    }
    
    // MARK: - Protocol Info
    
    func loadProtocolInfo() async {
        do {
            protocolInfo = try await apiService.getProtocolInfo()
        } catch {
            print("[EarnVM] Failed to load protocol info: \(error)")
        }
    }
    
    func loadBridgeHealth() async {
        do {
            bridgeHealth = try await apiService.getBridgeHealth()
        } catch {
            print("[EarnVM] Failed to load bridge health: \(error)")
        }
    }
    
    func loadApyHistory() async {
        do {
            apyHistory = try await apiService.getApyHistory(days: 30)
        } catch {
            print("[EarnVM] Failed to load APY history: \(error)")
        }
    }
    
    // MARK: - Lending Pools
    
    func loadLendingPools() async {
        isLoadingPools = true
        defer { isLoadingPools = false }
        
        do {
            let pools = try await apiService.fetchLendingPools(limit: 20)
            availablePools = pools.sorted { $0.apy > $1.apy } // Sort by APY descending
            
            // Auto-select best APY pool if none selected
            if selectedPool == nil, let bestPool = pools.max(by: { $0.apy < $1.apy }) {
                selectedPool = bestPool
            }
        } catch {
            print("[EarnVM] Failed to load lending pools: \(error)")
        }
    }
    
    func selectPool(_ pool: LendingPool) {
        selectedPool = pool
    }
    
    // MARK: - Positions
    
    func loadPositions() async {
        do {
            positions = try await apiService.getPositions(userWalletAddress: zcashWalletAddress)
        } catch {
            print("[EarnVM] Failed to load positions: \(error)")
        }
    }
    
    func loadUserStats() async {
        do {
            userStats = try await apiService.getUserStats(userWalletAddress: zcashWalletAddress)
        } catch {
            print("[EarnVM] Failed to load user stats: \(error)")
        }
    }
    
    func selectPosition(_ position: EarnPositionSummary) async {
        selectedPosition = position
        
        do {
            positionEarningsHistory = try await apiService.getEarningsHistory(
                positionId: position.positionId,
                userWalletAddress: zcashWalletAddress
            )
        } catch {
            print("[EarnVM] Failed to load earnings history: \(error)")
        }
    }
    
    // MARK: - Deposit Flow
    
    var depositAmountDouble: Double {
        Double(depositAmount) ?? 0
    }
    
    var canDeposit: Bool {
        guard let protocolInfo = protocolInfo else { return false }
        guard selectedPool != nil else { return false } // Must have a pool selected
        let amount = depositAmountDouble
        return amount >= protocolInfo.minDeposit && amount <= protocolInfo.maxDeposit
    }
    
    var depositValidationMessage: String? {
        guard let protocolInfo = protocolInfo else { return nil }
        let amount = depositAmountDouble
        
        if amount <= 0 { return nil }
        
        if selectedPool == nil {
            return "Please select a lending pool"
        }
        
        if amount < protocolInfo.minDeposit {
            return "Minimum deposit: \(protocolInfo.minDeposit) ZEC"
        }
        
        if amount > protocolInfo.maxDeposit {
            return "Maximum deposit: \(protocolInfo.maxDeposit) ZEC"
        }
        
        return nil
    }
    
    /// Get the current APY based on selected pool or protocol default
    var currentApy: Double {
        selectedPool?.apy ?? protocolInfo?.currentApy ?? 0
    }
    
    var formattedCurrentApy: String {
        String(format: "%.2f%%", currentApy)
    }
    
    /// Bridge fee percentage from protocol info or default
    var bridgeFeePercent: Double {
        bridgeDepositInfo?.bridgeFeePercent ?? 0.5 // Default 0.5% if not available
    }
    
    var formattedBridgeFeePercent: String {
        String(format: "%.1f%%", bridgeFeePercent)
    }
    
    /// Bridge fee amount in ZEC
    var bridgeFeeAmount: Double {
        depositAmountDouble * (bridgeFeePercent / 100)
    }
    
    /// Pool fee percentage from selected pool
    var poolFeePercent: Double {
        selectedPool?.fee ?? 0
    }
    
    /// Estimated amount after bridge fee
    var estimatedAmount: Double {
        if let info = bridgeDepositInfo {
            return info.expectedAmount
        }
        return depositAmountDouble - bridgeFeeAmount
    }
    
    /// The asset symbol user will receive (based on pool tokens)
    var receiveAssetSymbol: String {
        guard let pool = selectedPool else { return "LP Tokens" }
        // For liquidity pools, user receives LP tokens representing their share
        return "\(pool.displayName) LP"
    }
    
    /// Description of what user is depositing into
    var depositDescription: String {
        guard let pool = selectedPool else { return "Liquidity Pool" }
        return "\(pool.displayName) Pool"
    }
    
    /// Prepare deposit - get bridge address
    func prepareDeposit() async {
        guard canDeposit else { return }
        
        isPreparingDeposit = true
        errorMessage = nil
        
        do {
            bridgeDepositInfo = try await apiService.prepareDeposit(
                userWalletAddress: zcashWalletAddress,
                zecAmount: depositAmountDouble
            )
        } catch {
            errorMessage = "Failed to prepare deposit: \(error.localizedDescription)"
        }
        
        isPreparingDeposit = false
    }
    
    /// Send ZEC directly to the bridge address (auto-deposit)
    /// This automatically sends from the user's wallet to the bridge
    /// Works for both testnet (simulated) and mainnet (live) addresses
    func sendDepositToBridge() async {
        guard let bridgeInfo = bridgeDepositInfo else {
            errorMessage = "No bridge address available. Please prepare deposit first."
            return
        }
        
        guard let wallet = walletViewModel else {
            errorMessage = "Wallet not connected. Cannot auto-send."
            return
        }
        
        guard wallet.isReadyToSpend else {
            errorMessage = "Wallet is not ready to spend. Please wait for sync to complete."
            return
        }
        
        isSendingDeposit = true
        errorMessage = nil
        depositTransactionSent = false
        
        // Log testnet/mainnet mode
        let isTestnet = bridgeInfo.isSimulated ?? true
        print("[EarnVM] Sending deposit to bridge - Mode: \(isTestnet ? "TESTNET" : "MAINNET")")
        print("[EarnVM] Bridge address: \(bridgeInfo.bridgeAddress)")
        print("[EarnVM] Amount: \(depositAmountDouble) ZEC")
        
        do {
            let amountString = String(format: "%.8f", depositAmountDouble)
            
            // Create memo with pool info for tracking
            let memoPrefix = isTestnet ? "TESTNET " : ""
            let memo = "\(memoPrefix)RHEA deposit: \(selectedPool?.displayName ?? "Pool") | Intent: \(bridgeInfo.nearIntentId)"
            
            // Send ZEC to the bridge address
            _ = try await wallet.send(
                to: bridgeInfo.bridgeAddress,
                amount: amountString,
                memo: memo
            )
            
            // Mark transaction as sent
            depositTransactionSent = true
            print("[EarnVM] ✓ Deposit transaction sent successfully")
            
            // Automatically create the position record
            await createPosition()
            
        } catch {
            print("[EarnVM] ✗ Failed to send deposit: \(error)")
            errorMessage = "Failed to send deposit: \(error.localizedDescription)"
        }
        
        isSendingDeposit = false
    }
    
    /// Reset deposit flow state
    func resetDepositFlow() {
        depositAmount = ""
        bridgeDepositInfo = nil
        depositTransactionSent = false
        pendingFinalization = false
        finalizationTxHash = ""
        finalizationVout = 0
        finalizationResult = nil
        createdPositionId = nil
        errorMessage = nil
    }
    
    /// Create position after sending ZEC to bridge
    func createPosition() async {
        guard bridgeDepositInfo != nil else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let position = try await apiService.createPosition(
                userWalletAddress: zcashWalletAddress,
                zecAmount: depositAmountDouble,
                poolId: selectedPool?.id
            )
            
            // Store position ID for potential finalization
            createdPositionId = position.positionId
            
            // Check if finalization is required by the backend
            if bridgeDepositInfo?.requiresFinalization == true {
                pendingFinalization = true
                print("[EarnVM] Position created, awaiting finalization: \(position.positionId)")
            } else {
                // No finalization needed - refresh and switch to positions
                await loadPositions()
                await loadUserStats()
                selectedPosition = position
                depositAmount = ""
                bridgeDepositInfo = nil
                currentTab = .positions
            }
        } catch {
            errorMessage = "Failed to create position: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Deposit Finalization (reserved)
    
    /// Check if deposit requires finalization
    var requiresFinalization: Bool {
        bridgeDepositInfo?.requiresFinalization == true
    }
    
    /// Finalize deposit after ZEC transaction is confirmed.
    /// Currently only supported for future live bridge integrations.
    func finalizeDeposit() async {
        guard let bridgeInfo = bridgeDepositInfo,
              let depositArgs = bridgeInfo.depositArgs,
              let positionId = createdPositionId else {
            errorMessage = "Missing required data for finalization. Please try the deposit again."
            return
        }
        
        guard !finalizationTxHash.isEmpty else {
            errorMessage = "Please enter the Zcash transaction hash."
            return
        }
        
        isFinalizingDeposit = true
        errorMessage = nil
        
        print("[EarnVM] Finalizing deposit:")
        print("[EarnVM]   Position: \(positionId)")
        print("[EarnVM]   TX Hash: \(finalizationTxHash)")
        print("[EarnVM]   Vout: \(finalizationVout)")
        
        do {
            let result = try await apiService.finalizeDeposit(
                positionId: positionId,
                userWalletAddress: zcashWalletAddress,
                zcashTxHash: finalizationTxHash,
                vout: finalizationVout,
                depositArgs: depositArgs
            )
            
            finalizationResult = result
            
            if result.success {
                print("[EarnVM] ✓ Deposit finalized successfully!")
                print("[EarnVM]   NEAR TX: \(result.nearTxHash ?? "N/A")")
                print("[EarnVM]   nZEC Amount: \(result.nZecAmount ?? "N/A")")
                
                // Refresh positions and switch to positions tab
                await loadPositions()
                await loadUserStats()
                
                // Reset deposit flow
                resetDepositFlow()
                currentTab = .positions
            } else {
                errorMessage = result.error ?? "Finalization failed. Please check the transaction hash and try again."
            }
        } catch {
            print("[EarnVM] ✗ Finalization error: \(error)")
            errorMessage = "Finalization failed: \(error.localizedDescription)"
        }
        
        isFinalizingDeposit = false
    }
    
    // MARK: - Withdrawal Flow
    
    func initiateWithdrawal(position: EarnPositionSummary) async {
        isWithdrawing = true
        errorMessage = nil
        
        // Use the original Zcash address for withdrawal
        let withdrawAddress = withdrawToAddress.isEmpty ? zcashWalletAddress : withdrawToAddress
        
        do {
            let updatedPosition = try await apiService.initiateWithdrawal(
                positionId: position.positionId,
                userWalletAddress: zcashWalletAddress,
                withdrawToAddress: withdrawAddress,
                withdrawAll: true
            )
            
            // Update the position in the list
            if let index = positions.firstIndex(where: { $0.positionId == position.positionId }) {
                positions[index] = updatedPosition
            }
            
            selectedPosition = updatedPosition
            await loadUserStats()
        } catch {
            errorMessage = "Failed to initiate withdrawal: \(error.localizedDescription)"
        }
        
        isWithdrawing = false
    }
    
    // MARK: - Computed Properties
    
    var activePositions: [EarnPositionSummary] {
        positions.filter { $0.status.isActive }
    }
    
    var inProgressPositions: [EarnPositionSummary] {
        positions.filter { $0.status.isInProgress }
    }
    
    var completedPositions: [EarnPositionSummary] {
        positions.filter { $0.status == .completed }
    }
    
    var totalActiveValue: Double {
        activePositions.reduce(0) { $0 + $1.currentValue }
    }
    
    var totalEarnings: Double {
        positions.reduce(0) { $0 + $1.accruedEarnings }
    }
    
    var hasPositions: Bool {
        !positions.isEmpty
    }
}
