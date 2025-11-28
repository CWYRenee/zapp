import Foundation

struct SwapKitSwapService {
    static let shared = SwapKitSwapService()

    private let session: URLSession
    private let baseURL = URL(string: "https://api.swapkit.dev")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    struct SwapExecutionQuote {
        let expectedBuyAmount: String
        let depositAddress: String
        let memo: String?
    }

    enum SwapKitSwapError: Error {
        case missingApiKey
        case invalidResponse
        case decodingFailed
        case noRoute
    }

    func quoteZecSwap(
        buyAsset: String,
        amount: String,
        sourceZecAddress: String,
        destinationAddress: String,
        slippage: Double = 3
    ) async throws -> SwapExecutionQuote {
        guard let apiKey = ProcessInfo.processInfo.environment["SWAPKIT_KEY"],
              !apiKey.isEmpty else {
            throw SwapKitSwapError.missingApiKey
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("quote"))
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
            memo: route.memo
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
