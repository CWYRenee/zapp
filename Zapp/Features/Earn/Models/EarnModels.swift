import Foundation

// MARK: - Earn Position Status

enum EarnPositionStatus: String, Codable, CaseIterable {
    case pendingDeposit = "pending_deposit"
    case bridgingToNear = "bridging_to_near"
    case lendingActive = "lending_active"
    case pendingWithdrawal = "pending_withdrawal"
    case bridgingToZcash = "bridging_to_zcash"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .pendingDeposit: return "Awaiting Deposit"
        case .bridgingToNear: return "Bridging to NEAR"
        case .lendingActive: return "Earning on RHEA Finance"
        case .pendingWithdrawal: return "Processing Withdrawal"
        case .bridgingToZcash: return "Bridging to Zcash"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }
    
    var isActive: Bool {
        switch self {
        case .lendingActive:
            return true
        default:
            return false
        }
    }
    
    var isInProgress: Bool {
        switch self {
        case .pendingDeposit, .bridgingToNear, .pendingWithdrawal, .bridgingToZcash:
            return true
        default:
            return false
        }
    }
}

// MARK: - Earn Position Summary

struct EarnPositionSummary: Codable, Identifiable {
    let positionId: String
    let status: EarnPositionStatus
    let zecDeposited: Double
    let currentValue: Double
    let accruedEarnings: Double
    let currentApy: Double
    let depositedAt: Date?
    let lastUpdatedAt: Date
    
    var id: String { positionId }
    
    var earningsPercent: Double {
        guard zecDeposited > 0 else { return 0 }
        return (accruedEarnings / zecDeposited) * 100
    }
    
    enum CodingKeys: String, CodingKey {
        case positionId
        case status
        case zecDeposited
        case currentValue
        case accruedEarnings
        case currentApy
        case depositedAt
        case lastUpdatedAt
    }
}

// MARK: - Lending Protocol Info

struct LendingProtocolInfo: Codable {
    let protocolName: String
    let poolId: String
    let currentApy: Double
    let totalValueLocked: Double
    let minDeposit: Double
    let maxDeposit: Double
    let withdrawalFeePercent: Double
    let isActive: Bool
    
    var formattedApy: String {
        String(format: "%.2f%%", currentApy)
    }
    
    var formattedTvl: String {
        if totalValueLocked >= 1_000_000 {
            return String(format: "%.2fM ZEC", totalValueLocked / 1_000_000)
        } else if totalValueLocked >= 1_000 {
            return String(format: "%.2fK ZEC", totalValueLocked / 1_000)
        }
        return String(format: "%.2f ZEC", totalValueLocked)
    }
}

// MARK: - Lending Pool

/// Represents a lending pool available on RHEA Finance
struct LendingPool: Codable, Identifiable, Hashable {
    let id: String
    let tokenSymbols: [String]
    let tvl: Double
    let apy: Double
    let fee: Double
    
    /// Display name combining token symbols (e.g., "NEAR-USDC")
    var displayName: String {
        tokenSymbols.joined(separator: "-")
    }
    
    /// Formatted APY string
    var formattedApy: String {
        String(format: "%.2f%%", apy)
    }
    
    /// Formatted TVL string
    var formattedTvl: String {
        if tvl >= 1_000_000 {
            return String(format: "$%.2fM", tvl / 1_000_000)
        } else if tvl >= 1_000 {
            return String(format: "$%.2fK", tvl / 1_000)
        }
        return String(format: "$%.2f", tvl)
    }
    
    /// Formatted pool fee string
    var formattedFee: String {
        String(format: "%.2f%%", fee)
    }
    
    /// Check if this is a stablecoin pool (typically lower risk)
    var isStablecoinPool: Bool {
        let stablecoins = ["USDC", "USDT", "DAI", "USN", "FRAX"]
        return tokenSymbols.allSatisfy { symbol in
            stablecoins.contains(where: { symbol.uppercased().contains($0) })
        }
    }
    
    /// APY tier for visual indication
    var apyTier: ApyTier {
        switch apy {
        case 0..<5: return .low
        case 5..<15: return .medium
        case 15..<30: return .high
        default: return .veryHigh
        }
    }
    
    enum ApyTier {
        case low, medium, high, veryHigh
        
        var color: String {
            switch self {
            case .low: return "gray"
            case .medium: return "blue"
            case .high: return "green"
            case .veryHigh: return "orange"
            }
        }
    }
}

// MARK: - Bridge Deposit Info

struct BridgeDepositInfo: Codable {
    let bridgeAddress: String
    let expectedAmount: Double
    let estimatedArrivalMinutes: Int
    let bridgeFeePercent: Double
    let nearIntentId: String
    /// Whether this is a simulated testnet address (not a real deposit address)
    let isSimulated: Bool?
    /// Source of the bridge address
    let source: BridgeAddressSource?
    /// Optional opaque payload reserved for future bridge finalization (base64 encoded)
    /// Not used in the current simulation-only implementation.
    let depositArgs: String?
    /// Minimum deposit amount in ZEC
    let minDepositZec: Double?
    
    /// True if this address is from live bridging (non-simulated)
    var isLiveAddress: Bool {
        !(isSimulated ?? true)
    }
    
    /// True if this deposit requires explicit finalization (for future live bridges).
    /// Always false in the current simulation-only implementation.
    var requiresFinalization: Bool {
        false
    }
    
    /// Display text for the address source
    var sourceDescription: String {
        switch source {
        case .swapkit_api:
            return "SwapKit API"
        case .testnet_simulation:
            return "Testnet Simulation"
        case .fallback:
            return "Fallback (Not Real)"
        case .none:
            return "Unknown"
        }
    }
}

/// Source of the bridge deposit address
enum BridgeAddressSource: String, Codable {
    case swapkit_api
    case testnet_simulation
    case fallback
}

// MARK: - Finalize Deposit

/// Input for finalizing a bridge deposit
struct FinalizeDepositInput: Codable {
    let positionId: String
    let userWalletAddress: String
    let zcashTxHash: String
    let vout: Int
    let depositArgs: String
    
    enum CodingKeys: String, CodingKey {
        case positionId = "position_id"
        case userWalletAddress = "user_wallet_address"
        case zcashTxHash = "zcash_tx_hash"
        case vout
        case depositArgs = "deposit_args"
    }
}

/// Result from finalizing a deposit
struct FinalizeDepositResult: Codable {
    let success: Bool
    let nearTxHash: String?
    let nZecAmount: String?
    let error: String?
    let explorerUrl: String?
}

// MARK: - Bridge Health

struct BridgeHealth: Codable {
    let isOperational: Bool
    let estimatedDelayMinutes: Int
    let message: String?
}

// MARK: - User Earn Stats

struct UserEarnStats: Codable {
    let totalDeposited: Double
    let totalCurrentValue: Double
    let totalEarnings: Double
    let activePositions: Int
    let completedPositions: Int
    
    var earningsPercent: Double {
        guard totalDeposited > 0 else { return 0 }
        return (totalEarnings / totalDeposited) * 100
    }
}

// MARK: - APY History Point

struct ApyHistoryPoint: Codable, Identifiable {
    let timestamp: Date
    let apy: Double
    
    var id: Date { timestamp }
}

// MARK: - Earnings History Point

struct EarningsHistoryPoint: Codable, Identifiable {
    let timestamp: Date
    let balance: Double
    let earnings: Double
    
    var id: Date { timestamp }
}

// No wallet mapping needed - direct bridge from Zcash to NEAR/RHEA Finance

// MARK: - API Response Types

struct EarnProtocolResponse: Codable {
    let success: Bool
    let protocolInfo: LendingProtocolInfo?
    let error: String?
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case success
        case protocolInfo = "protocol"
        case error
        case message
    }
}

struct BridgeDepositResponse: Codable {
    let success: Bool
    let deposit: BridgeDepositInfo?
    let instructions: String?
    let error: String?
    let message: String?
}

struct EarnPositionResponse: Codable {
    let success: Bool
    let position: EarnPositionSummary?
    let error: String?
    let message: String?
}

struct EarnPositionsListResponse: Codable {
    let success: Bool
    let positions: [EarnPositionSummary]?
    let total: Int?
    let error: String?
    let message: String?
}

struct BridgeHealthResponse: Codable {
    let success: Bool
    let bridge: BridgeHealth?
    let error: String?
    let message: String?
}

struct UserStatsResponse: Codable {
    let success: Bool
    let stats: UserEarnStats?
    let error: String?
    let message: String?
}

struct ApyHistoryResponse: Codable {
    let success: Bool
    let history: [ApyHistoryPoint]?
    let error: String?
    let message: String?
}

struct EarningsHistoryResponse: Codable {
    let success: Bool
    let history: [EarningsHistoryPoint]?
    let error: String?
    let message: String?
}

struct LendingPoolsResponse: Codable {
    let success: Bool
    let pools: [LendingPool]?
    let error: String?
    let message: String?
}

struct FinalizeDepositApiResponse: Codable {
    let success: Bool
    let nearTxHash: String?
    let nZecAmount: String?
    let explorerUrl: String?
    let error: String?
    let message: String?
}
