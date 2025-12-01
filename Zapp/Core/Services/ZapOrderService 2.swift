import Foundation

struct ZapOrderDTO: Decodable {
    let orderId: String
    let merchantCode: String
    let merchantName: String?
    let fiatAmount: Double
    let fiatCurrency: String
    let zecAmount: Double
    let exchangeRate: Double
    let status: String
}

private struct ZapOrderCreateRequest: Encodable {
    let userWalletAddress: String
    let merchantCode: String
    let merchantName: String?
    let fiatAmount: Double
    let fiatCurrency: String
    let metadata: [String: String]?

    enum CodingKeys: String, CodingKey {
        case userWalletAddress = "user_wallet_address"
        case merchantCode = "merchant_code"
        case merchantName = "merchant_name"
        case fiatAmount = "fiat_amount"
        case fiatCurrency = "fiat_currency"
        case metadata
    }
}

private struct ZapOrderCreateResponse: Decodable {
    let success: Bool
    let order: ZapOrderDTO?
    let message: String?
}

enum ZapOrderError: Error, LocalizedError {
    case invalidMerchant
    case invalidAmount
    case backend(String)

    var errorDescription: String? {
        switch self {
        case .invalidMerchant:
            return "Facilitator information is invalid."
        case .invalidAmount:
            return "Please enter a valid amount greater than zero."
        case .backend(let message):
            return message
        }
    }
}

protocol ZapOrderServicing {
    func createOrder(
        userWalletAddress: String,
        merchantCode: String,
        merchantName: String?,
        fiatAmount: Decimal,
        fiatCurrency: String
    ) async throws -> ZapOrderDTO
}

final class ZapOrderService: ZapOrderServicing {
    private let session: URLSession
    private let baseURL: URL

    init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "http://localhost:4001")!
    ) {
        self.session = session
        self.baseURL = baseURL
    }

    func createOrder(
        userWalletAddress: String,
        merchantCode: String,
        merchantName: String?,
        fiatAmount: Decimal,
        fiatCurrency: String
    ) async throws -> ZapOrderDTO {
        let trimmedWallet = userWalletAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCode = merchantCode.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedWallet.isEmpty, !trimmedCode.isEmpty else {
            throw ZapOrderError.invalidMerchant
        }

        guard fiatAmount > 0 else {
            throw ZapOrderError.invalidAmount
        }

        let amountNumber = NSDecimalNumber(decimal: fiatAmount).doubleValue
        let currency = fiatCurrency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        var url = baseURL
        url.appendPathComponent("api/zapp/orders")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let trimmedName = merchantName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = ZapOrderCreateRequest(
            userWalletAddress: trimmedWallet,
            merchantCode: trimmedCode,
            merchantName: trimmedName?.isEmpty == false ? trimmedName : nil,
            fiatAmount: amountNumber,
            fiatCurrency: currency,
            metadata: [
                "platform": "ios",
                "app": "zapp"
            ]
        )

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ZapOrderError.backend("Invalid server response.")
        }

        let decoder = JSONDecoder()
        let payload = try decoder.decode(ZapOrderCreateResponse.self, from: data)

        guard httpResponse.statusCode >= 200, httpResponse.statusCode < 300 else {
            let message = payload.message ?? "Failed to create order (status: \(httpResponse.statusCode))."
            throw ZapOrderError.backend(message)
        }

        guard payload.success, let order = payload.order else {
            let message = payload.message ?? "Failed to create order."
            throw ZapOrderError.backend(message)
        }

        return order
    }
}
