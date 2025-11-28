import Foundation

struct SwapKitPriceService {
    static let shared = SwapKitPriceService()

    private let session: URLSession
    private let baseURL = URL(string: "https://api.swapkit.dev/price")!
    private let zecIdentifier = "ZEC.ZEC"

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchZecUsdPrice() async throws -> Double {
        guard let apiKey = ProcessInfo.processInfo.environment["SWAPKIT_KEY"],
              !apiKey.isEmpty else {
            throw SwapKitPriceError.missingApiKey
        }

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        let body = PriceRequest(tokens: [TokenIdentifier(identifier: zecIdentifier)], metadata: true)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              200 ..< 300 ~= httpResponse.statusCode else {
            throw SwapKitPriceError.invalidResponse
        }

        let items = try JSONDecoder().decode([PriceResponseItem].self, from: data)

        guard let item = items.first(where: { $0.identifier == zecIdentifier }),
              item.priceUsd > 0 else {
            throw SwapKitPriceError.priceUnavailable
        }

        return item.priceUsd
    }
}

extension SwapKitPriceService {
    enum SwapKitPriceError: Error {
        case missingApiKey
        case invalidResponse
        case priceUnavailable
    }

    private struct TokenIdentifier: Encodable {
        let identifier: String
    }

    private struct PriceRequest: Encodable {
        let tokens: [TokenIdentifier]
        let metadata: Bool
    }

    private struct PriceResponseItem: Decodable {
        let identifier: String
        let priceUsd: Double

        enum CodingKeys: String, CodingKey {
            case identifier
            case priceUsd = "price_usd"
        }
    }
}
