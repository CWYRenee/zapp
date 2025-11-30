import Foundation

/// Service for communicating with the Earn backend API
final class EarnAPIService {
    static let shared = EarnAPIService()
    
    private let baseURL: String
    private let session: URLSession
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder
    
    private init() {
        // Load from environment or use default
        self.baseURL = ProcessInfo.processInfo.environment["ZAPP_API_URL"] ?? "http://localhost:4001"
        self.session = URLSession.shared
        
        self.jsonDecoder = JSONDecoder()
        self.jsonDecoder.dateDecodingStrategy = .iso8601
        
        self.jsonEncoder = JSONEncoder()
        self.jsonEncoder.dateEncodingStrategy = .iso8601
    }
    
    // MARK: - Protocol Info
    
    /// Get lending protocol information
    func getProtocolInfo() async throws -> LendingProtocolInfo {
        let url = URL(string: "\(baseURL)/api/zapp/earn/protocol")!
        let (data, _) = try await session.data(from: url)
        let response = try jsonDecoder.decode(EarnProtocolResponse.self, from: data)
        
        guard response.success, let protocolInfo = response.protocolInfo else {
            throw EarnAPIError.requestFailed(response.message ?? "Failed to get protocol info")
        }
        
        return protocolInfo
    }
    
    /// Get APY history for charts
    func getApyHistory(days: Int = 30) async throws -> [ApyHistoryPoint] {
        let url = URL(string: "\(baseURL)/api/zapp/earn/protocol/apy-history?days=\(days)")!
        let (data, _) = try await session.data(from: url)
        let response = try jsonDecoder.decode(ApyHistoryResponse.self, from: data)
        
        guard response.success, let history = response.history else {
            throw EarnAPIError.requestFailed(response.message ?? "Failed to get APY history")
        }
        
        return history
    }
    
    /// Get bridge health status
    func getBridgeHealth() async throws -> BridgeHealth {
        let url = URL(string: "\(baseURL)/api/zapp/earn/bridge/health")!
        let (data, _) = try await session.data(from: url)
        let response = try jsonDecoder.decode(BridgeHealthResponse.self, from: data)
        
        guard response.success, let bridge = response.bridge else {
            throw EarnAPIError.requestFailed(response.message ?? "Failed to get bridge health")
        }
        
        return bridge
    }
    
    // MARK: - Lending Pools
    
    /// Fetch available lending pools with live APYs
    func fetchLendingPools(limit: Int = 10) async throws -> [LendingPool] {
        let url = URL(string: "\(baseURL)/api/zapp/earn/pools/top?limit=\(limit)")!
        let (data, _) = try await session.data(from: url)
        let response = try jsonDecoder.decode(LendingPoolsResponse.self, from: data)
        
        guard response.success, let pools = response.pools else {
            throw EarnAPIError.requestFailed(response.message ?? "Failed to fetch lending pools")
        }
        
        return pools
    }
    
    // MARK: - Deposit Flow
    
    /// Prepare deposit - get bridge address
    func prepareDeposit(userWalletAddress: String, zecAmount: Double) async throws -> BridgeDepositInfo {
        let url = URL(string: "\(baseURL)/api/zapp/earn/deposit/prepare")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "user_wallet_address": userWalletAddress,
            "zec_amount": zecAmount
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await session.data(for: request)
        let response = try jsonDecoder.decode(BridgeDepositResponse.self, from: data)
        
        guard response.success, let deposit = response.deposit else {
            throw EarnAPIError.requestFailed(response.message ?? "Failed to prepare deposit")
        }
        
        return deposit
    }
    
    /// Create a new earn position
    func createPosition(
        userWalletAddress: String,
        zecAmount: Double,
        poolId: String?
    ) async throws -> EarnPositionSummary {
        let url = URL(string: "\(baseURL)/api/zapp/earn/positions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [
            "user_wallet_address": userWalletAddress,
            "zec_amount": zecAmount
        ]
        if let poolId = poolId {
            body["pool_id"] = poolId
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await session.data(for: request)
        let response = try jsonDecoder.decode(EarnPositionResponse.self, from: data)
        
        guard response.success, let position = response.position else {
            throw EarnAPIError.requestFailed(response.message ?? "Failed to create position")
        }
        
        return position
    }
    
    /// Finalize a deposit after ZEC has been sent and confirmed.
    /// Reserved for future bridge implementations that require explicit finalization.
    func finalizeDeposit(
        positionId: String,
        userWalletAddress: String,
        zcashTxHash: String,
        vout: Int,
        depositArgs: String
    ) async throws -> FinalizeDepositResult {
        let url = URL(string: "\(baseURL)/api/zapp/earn/deposit/finalize")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "position_id": positionId,
            "user_wallet_address": userWalletAddress,
            "zcash_tx_hash": zcashTxHash,
            "vout": vout,
            "deposit_args": depositArgs
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await session.data(for: request)
        let response = try jsonDecoder.decode(FinalizeDepositApiResponse.self, from: data)
        
        return FinalizeDepositResult(
            success: response.success,
            nearTxHash: response.nearTxHash,
            nZecAmount: response.nZecAmount,
            error: response.message,
            explorerUrl: response.explorerUrl
        )
    }
    
    // MARK: - Position Management
    
    /// Get all positions for a user
    func getPositions(userWalletAddress: String, status: EarnPositionStatus? = nil) async throws -> [EarnPositionSummary] {
        var urlString = "\(baseURL)/api/zapp/earn/positions/user/\(userWalletAddress)"
        if let status = status {
            urlString += "?status=\(status.rawValue)"
        }
        
        let url = URL(string: urlString)!
        let (data, _) = try await session.data(from: url)
        let response = try jsonDecoder.decode(EarnPositionsListResponse.self, from: data)
        
        guard response.success, let positions = response.positions else {
            throw EarnAPIError.requestFailed(response.message ?? "Failed to get positions")
        }
        
        return positions
    }
    
    /// Get a single position
    func getPosition(positionId: String, userWalletAddress: String) async throws -> EarnPositionSummary {
        let encodedAddress = userWalletAddress.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? userWalletAddress
        let url = URL(string: "\(baseURL)/api/zapp/earn/positions/\(positionId)?user_wallet_address=\(encodedAddress)")!
        let (data, _) = try await session.data(from: url)
        let response = try jsonDecoder.decode(EarnPositionResponse.self, from: data)
        
        guard response.success, let position = response.position else {
            throw EarnAPIError.requestFailed(response.message ?? "Failed to get position")
        }
        
        return position
    }
    
    /// Get earnings history for a position
    func getEarningsHistory(positionId: String, userWalletAddress: String, days: Int = 30) async throws -> [EarningsHistoryPoint] {
        let encodedAddress = userWalletAddress.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? userWalletAddress
        let url = URL(string: "\(baseURL)/api/zapp/earn/positions/\(positionId)/earnings-history?user_wallet_address=\(encodedAddress)&days=\(days)")!
        let (data, _) = try await session.data(from: url)
        let response = try jsonDecoder.decode(EarningsHistoryResponse.self, from: data)
        
        guard response.success, let history = response.history else {
            throw EarnAPIError.requestFailed(response.message ?? "Failed to get earnings history")
        }
        
        return history
    }
    
    /// Get user stats
    func getUserStats(userWalletAddress: String) async throws -> UserEarnStats {
        let url = URL(string: "\(baseURL)/api/zapp/earn/user/\(userWalletAddress)/stats")!
        let (data, _) = try await session.data(from: url)
        let response = try jsonDecoder.decode(UserStatsResponse.self, from: data)
        
        guard response.success, let stats = response.stats else {
            throw EarnAPIError.requestFailed(response.message ?? "Failed to get user stats")
        }
        
        return stats
    }
    
    // MARK: - Withdrawal
    
    /// Initiate withdrawal
    func initiateWithdrawal(
        positionId: String,
        userWalletAddress: String,
        withdrawToAddress: String,
        withdrawAll: Bool = true,
        partialAmount: Double? = nil
    ) async throws -> EarnPositionSummary {
        let url = URL(string: "\(baseURL)/api/zapp/earn/positions/\(positionId)/withdraw")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [
            "user_wallet_address": userWalletAddress,
            "withdraw_to_address": withdrawToAddress,
            "withdraw_all": withdrawAll
        ]
        
        if let amount = partialAmount {
            body["partial_amount"] = amount
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await session.data(for: request)
        let response = try jsonDecoder.decode(EarnPositionResponse.self, from: data)
        
        guard response.success, let position = response.position else {
            throw EarnAPIError.requestFailed(response.message ?? "Failed to initiate withdrawal")
        }
        
        return position
    }
}

// MARK: - Errors

enum EarnAPIError: Error, LocalizedError {
    case requestFailed(String)
    case invalidResponse
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .requestFailed(let message):
            return message
        case .invalidResponse:
            return "Invalid response from server."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
