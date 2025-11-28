import Foundation

struct SwapKitToken: Decodable, Identifiable {
    let chain: String
    let chainId: String?
    let ticker: String?
    let identifier: String
    let symbol: String?
    let name: String?
    let decimals: Int?
    let logoURI: String?
    let coingeckoId: String?

    var id: String { identifier }
}

struct SwapKitTokenService {
    static let shared = SwapKitTokenService()

    private let session: URLSession
    private let baseURL = URL(string: "https://api.swapkit.dev/tokens?")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    enum SwapKitTokenError: Error {
        case missingApiKey
        case invalidResponse
        case decodingFailed
    }

    func fetchTokens(provider: String = "NEAR") async throws -> [SwapKitToken] {
        guard let apiKey = ProcessInfo.processInfo.environment["SWAPKIT_KEY"],
              !apiKey.isEmpty else {
            throw SwapKitTokenError.missingApiKey
        }

        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw SwapKitTokenError.invalidResponse
        }
        components.queryItems = [URLQueryItem(name: "provider", value: provider)]
        guard let url = components.url else {
            throw SwapKitTokenError.invalidResponse
        }

        print("SwapKitTokenService.fetchTokens URL: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        if let headers = request.allHTTPHeaderFields {
            print("SwapKitTokenService.fetchTokens headers: \(headers)")
        } else {
            print("SwapKitTokenService.fetchTokens headers: [:]")
        }

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            print("SwapKitTokenService.fetchTokens status: \(httpResponse.statusCode)")
        } else {
            print("SwapKitTokenService.fetchTokens status: <non-HTTP response>")
        }

        if let bodyString = String(data: data, encoding: .utf8) {
            print("SwapKitTokenService.fetchTokens raw body: \n\(bodyString)")
        } else {
            print("SwapKitTokenService.fetchTokens raw body: <non-UTF8 data, length=\(data.count) bytes>")
        }

        guard let httpResponse = response as? HTTPURLResponse,
              200 ..< 300 ~= httpResponse.statusCode else {
            throw SwapKitTokenError.invalidResponse
        }

        let decoder = JSONDecoder()
        do {
            let wrapper = try decoder.decode(TokensResponse.self, from: data)
            return wrapper.tokens
        } catch {
            print("SwapKitTokenService.fetchTokens decoding error: \(error)")
            throw SwapKitTokenError.decodingFailed
        }
    }
}

private struct TokensResponse: Decodable {
    let tokens: [SwapKitToken]
}
