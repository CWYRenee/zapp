import Foundation

/// SwapKit Swap Service
/// Handles cross-chain swap quotes for ZEC/TAZ → NEAR bridging
///
/// Architecture:
/// - Mainnet: Calls SwapKit API directly (requires SWAPKIT_KEY)
/// - Testnet: Routes through backend API which provides simulated quotes for TAZ → NEAR testnet
struct SwapKitSwapService {
    static let shared = SwapKitSwapService()

    private let session: URLSession
    private let swapKitURL = URL(string: "https://api.swapkit.dev")!
    private let backendURL: String
    private let isTestnet: Bool

    init(session: URLSession = .shared) {
        self.session = session
        // Get backend URL from environment, defaulting to localhost for development
        self.backendURL = ProcessInfo.processInfo.environment["ZAPP_API_URL"] ?? "http://localhost:4001"
        // Check if we're in testnet mode
        self.isTestnet = (ProcessInfo.processInfo.environment["NEAR_ENV"] ?? "testnet") == "testnet"
    }

    struct SwapExecutionQuote {
        let expectedBuyAmount: String
        let depositAddress: String
        let memo: String?
        let estimatedTimeMinutes: Int?
        let priceImpact: Double?
    }

    enum SwapKitSwapError: Error {
        case missingApiKey
        case invalidResponse
        case decodingFailed
        case noRoute
        case networkError(Error)
    }

    /// Get a swap quote for ZEC/TAZ → target asset
    /// - In testnet mode: Routes through backend for simulation
    /// - In mainnet mode: Calls SwapKit API directly
    func quoteZecSwap(
        buyAsset: String,
        amount: String,
        sourceZecAddress: String,
        destinationAddress: String,
        slippage: Double = 3
    ) async throws -> SwapExecutionQuote {
        // For testnet, route through backend which provides simulation
        if isTestnet {
            return try await getQuoteFromBackend(
                sellAmount: amount,
                sourceZecAddress: sourceZecAddress,
                destinationAddress: destinationAddress,
                slippage: slippage
            )
        }
        
        // Mainnet: use SwapKit API directly
        return try await getQuoteFromSwapKit(
            buyAsset: buyAsset,
            amount: amount,
            sourceZecAddress: sourceZecAddress,
            destinationAddress: destinationAddress,
            slippage: slippage
        )
    }
    
    // MARK: - Backend API (Testnet)
    
    /// Get quote from backend API (for testnet simulation)
    private func getQuoteFromBackend(
        sellAmount: String,
        sourceZecAddress: String,
        destinationAddress: String,
        slippage: Double
    ) async throws -> SwapExecutionQuote {
        guard let url = URL(string: "\(backendURL)/api/zapp/earn/bridge/quote") else {
            throw SwapKitSwapError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "sellAmount": sellAmount,
            "sourceZecAddress": sourceZecAddress,
            "destinationNearAddress": destinationAddress,
            "slippage": slippage
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200 ..< 300 ~= httpResponse.statusCode else {
            throw SwapKitSwapError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        let quoteResponse = try decoder.decode(BackendQuoteResponse.self, from: data)
        
        guard let bestRoute = quoteResponse.bestRoute,
              let depositAddress = bestRoute.depositAddress,
              !depositAddress.isEmpty else {
            throw SwapKitSwapError.noRoute
        }
        
        return SwapExecutionQuote(
            expectedBuyAmount: bestRoute.expectedBuyAmount,
            depositAddress: depositAddress,
            memo: bestRoute.memo,
            estimatedTimeMinutes: bestRoute.estimatedTimeMinutes,
            priceImpact: bestRoute.priceImpact
        )
    }
    
    // MARK: - SwapKit API (Mainnet)
    
    /// Get quote from SwapKit API directly (for mainnet)
    private func getQuoteFromSwapKit(
        buyAsset: String,
        amount: String,
        sourceZecAddress: String,
        destinationAddress: String,
        slippage: Double
    ) async throws -> SwapExecutionQuote {
        guard let apiKey = ProcessInfo.processInfo.environment["SWAPKIT_KEY"],
              !apiKey.isEmpty else {
            throw SwapKitSwapError.missingApiKey
        }

        var request = URLRequest(url: swapKitURL.appendingPathComponent("quote"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        let body = QuoteRequest(
            sellAsset: "ZEC.ZEC",
            buyAsset: buyAsset,
            sellAmount: amount,
            providers: ["NEAR"],
            sourceAddress: sourceZecAddress,
            destinationAddress: destinationAddress,
            slippage: slippage,
            includeTx: false
        )

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              200 ..< 300 ~= httpResponse.statusCode else {
            throw SwapKitSwapError.invalidResponse
        }

        let decoder = JSONDecoder()
        let quoteResponse: QuoteResponse
        do {
            quoteResponse = try decoder.decode(QuoteResponse.self, from: data)
        } catch {
            throw SwapKitSwapError.decodingFailed
        }

        guard let route = bestRoute(forProvider: "NEAR", from: quoteResponse),
              let expectedBuyAmount = route.expectedBuyAmount,
              let depositAddress = route.targetAddress ?? route.inboundAddress,
              !depositAddress.isEmpty else {
            throw SwapKitSwapError.noRoute
        }

        return SwapExecutionQuote(
            expectedBuyAmount: expectedBuyAmount,
            depositAddress: depositAddress,
            memo: route.memo,
            estimatedTimeMinutes: route.estimatedTime.map { Int(ceil(Double($0.total ?? 600) / 60.0)) },
            priceImpact: route.meta?.priceImpact
        )
    }

    private func bestRoute(forProvider provider: String, from response: QuoteResponse) -> QuoteResponse.Route? {
        let providerRoutes = response.routes.filter { $0.providers.contains(provider) }
        if providerRoutes.isEmpty {
            return nil
        }
        if let tagged = providerRoutes.first(where: { $0.meta?.tags?.contains("RECOMMENDED") == true }) {
            return tagged
        }
        return providerRoutes.first
    }
}

extension SwapKitSwapService {
    // MARK: - Backend API Response Types (Testnet)
    
    private struct BackendQuoteResponse: Decodable {
        let success: Bool
        let bestRoute: BackendRoute?
        let routes: [BackendRoute]?
        
        struct BackendRoute: Decodable {
            let expectedBuyAmount: String
            let depositAddress: String?
            let memo: String?
            let estimatedTimeMinutes: Int?
            let priceImpact: Double?
        }
    }
    
    // MARK: - SwapKit API Types (Mainnet)
    
    private struct QuoteRequest: Encodable {
        let sellAsset: String
        let buyAsset: String
        let sellAmount: String
        let providers: [String]
        let sourceAddress: String
        let destinationAddress: String
        let slippage: Double
        let includeTx: Bool
    }

    private struct QuoteResponse: Decodable {
        let routes: [Route]

        struct Route: Decodable {
            let providers: [String]
            let expectedBuyAmount: String?
            let expectedBuyAmountMaxSlippage: String?
            let targetAddress: String?
            let inboundAddress: String?
            let memo: String?
            let estimatedTime: EstimatedTime?
            let meta: Meta?
        }

        struct EstimatedTime: Decodable {
            let inbound: Int?
            let swap: Int?
            let outbound: Int?
            let total: Int?
        }

        struct Meta: Decodable {
            let tags: [String]?
            let priceImpact: Double?
        }
    }
}
