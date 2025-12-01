import Foundation

struct ZapOrderDTO: Decodable {
    let orderId: String
    let merchantCode: String
    let merchantName: String?
    let fiatAmount: Double
    let fiatCurrency: String
    let zecAmount: Double
    let exchangeRate: Double
    // Spread-related fields
    let baseExchangeRate: Double?
    let userDisplayRate: Double?
    let merchantDisplayRate: Double?
    let merchantZecAmount: Double?
    let platformZecAmount: Double?
    let platformZecAddress: String?
    let status: String
    let merchantZecAddress: String?
    // Raw QR code data scanned by user (for facilitator to scan and pay)
    let scannedQRCodeData: String?
    // Batch order reference
    let batchId: String?
    let paymentRail: String?
    let createdAt: String?
    let updatedAt: String?
}

// MARK: - Batch Order Types

struct BatchOrderItem {
    let merchantCode: String
    let merchantName: String?
    let fiatAmount: Decimal
    let fiatCurrency: String
    let paymentRail: String
    let scannedQRCodeData: String?
}

struct BatchOrderDTO: Decodable {
    let batchId: String
    let userWalletAddress: String
    let totalZecAmount: Double
    let orders: [ZapOrderDTO]
    let merchantGroups: [MerchantGroupDTO]
    let status: String
    let createdAt: String?
    let updatedAt: String?
}

struct MerchantGroupDTO: Decodable, Identifiable {
    let groupId: String
    let merchantId: String?
    let merchantZecAddress: String?
    let paymentRails: [String]
    let totalZecAmount: Double
    let orderIds: [String]
    let status: String
    
    var id: String { groupId }
}

private struct BatchOrderItemRequest: Encodable {
    let merchantCode: String
    let merchantName: String?
    let fiatAmount: Double
    let fiatCurrency: String
    let paymentRail: String
    let scannedQRCodeData: String?
    
    enum CodingKeys: String, CodingKey {
        case merchantCode = "merchant_code"
        case merchantName = "merchant_name"
        case fiatAmount = "fiat_amount"
        case fiatCurrency = "fiat_currency"
        case paymentRail = "payment_rail"
        case scannedQRCodeData = "scanned_qr_code_data"
    }
}

private struct BatchOrderCreateRequest: Encodable {
    let userWalletAddress: String
    let items: [BatchOrderItemRequest]
    let metadata: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case userWalletAddress = "user_wallet_address"
        case items
        case metadata
    }
}

private struct BatchOrderCreateResponse: Decodable {
    let success: Bool
    let batchOrder: BatchOrderDTO?
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case success
        case batchOrder = "batch_order"
        case message
    }
}

private struct BatchOrderGetResponse: Decodable {
    let success: Bool
    let batchOrder: BatchOrderDTO?
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case success
        case batchOrder = "batch_order"
        case message
    }
}

private struct ZapOrderCreateRequest: Encodable {
    let userWalletAddress: String
    let merchantCode: String
    let merchantName: String?
    let fiatAmount: Double
    let fiatCurrency: String
    let paymentRail: String
    let scannedQRCodeData: String?
    let metadata: [String: String]?

    enum CodingKeys: String, CodingKey {
        case userWalletAddress = "user_wallet_address"
        case merchantCode = "merchant_code"
        case merchantName = "merchant_name"
        case fiatAmount = "fiat_amount"
        case fiatCurrency = "fiat_currency"
        case paymentRail = "payment_rail"
        case scannedQRCodeData = "scanned_qr_code_data"
        case metadata
    }
}

private struct ZapOrderCreateResponse: Decodable {
    let success: Bool
    let order: ZapOrderDTO?
    let message: String?
}

private struct ZapOrderListResponse: Decodable {
    let success: Bool
    let orders: [ZapOrderDTO]
    let total: Int
    let message: String?
}

private struct ZapOrderCancelRequest: Encodable {
    let userWalletAddress: String
    let reason: String?
    
    enum CodingKeys: String, CodingKey {
        case userWalletAddress = "user_wallet_address"
        case reason
    }
}

private struct ZapOrderCancelResponse: Decodable {
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
        fiatCurrency: String,
        paymentRail: String,
        scannedQRCodeData: String?
    ) async throws -> ZapOrderDTO

    func listOrdersForUser(
        userWalletAddress: String,
        status: String?
    ) async throws -> [ZapOrderDTO]

    func cancelOrder(
        orderId: String,
        userWalletAddress: String,
        reason: String?
    ) async throws -> ZapOrderDTO
    
    func createBatchOrder(
        userWalletAddress: String,
        items: [BatchOrderItem]
    ) async throws -> BatchOrderDTO
    
    func getBatchOrder(
        batchId: String,
        userWalletAddress: String
    ) async throws -> BatchOrderDTO?
}

final class ZapOrderService: ZapOrderServicing {
    private let session: URLSession
    private let baseURL: URL

    private static func defaultBaseURL() -> URL {
        let baseURLString = ProcessInfo.processInfo.environment["ZAPP_API_URL"] ?? "https://zapp-backend-ik5q.onrender.com"
        return URL(string: baseURLString) ?? URL(string: "https://zapp-backend-ik5q.onrender.com")!
    }

    init(
        session: URLSession = .shared,
        baseURL: URL = ZapOrderService.defaultBaseURL()
    ) {
        self.session = session
        self.baseURL = baseURL
    }

    func createOrder(
        userWalletAddress: String,
        merchantCode: String,
        merchantName: String?,
        fiatAmount: Decimal,
        fiatCurrency: String,
        paymentRail: String,
        scannedQRCodeData: String? = nil
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
        let rail = paymentRail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        var url = baseURL
        url.appendPathComponent("api/zapp/orders")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let trimmedName = merchantName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedQRCode = scannedQRCodeData?.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = ZapOrderCreateRequest(
            userWalletAddress: trimmedWallet,
            merchantCode: trimmedCode,
            merchantName: trimmedName?.isEmpty == false ? trimmedName : nil,
            fiatAmount: amountNumber,
            fiatCurrency: currency,
            paymentRail: rail,
            scannedQRCodeData: trimmedQRCode?.isEmpty == false ? trimmedQRCode : nil,
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

    func listOrdersForUser(
        userWalletAddress: String,
        status: String? = nil
    ) async throws -> [ZapOrderDTO] {
        let trimmedWallet = userWalletAddress.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedWallet.isEmpty else {
            throw ZapOrderError.invalidMerchant
        }

        var url = baseURL
        url.appendPathComponent("api/zapp/orders/user")
        url.appendPathComponent(trimmedWallet)

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let status, !status.isEmpty {
            components?.queryItems = [URLQueryItem(name: "status", value: status)]
        }

        guard let finalURL = components?.url else {
            throw ZapOrderError.backend("Invalid URL.")
        }

        var request = URLRequest(url: finalURL)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ZapOrderError.backend("Invalid server response.")
        }

        let decoder = JSONDecoder()
        let payload = try decoder.decode(ZapOrderListResponse.self, from: data)

        guard httpResponse.statusCode >= 200, httpResponse.statusCode < 300 else {
            let message = payload.message ?? "Failed to load orders (status: \(httpResponse.statusCode))."
            throw ZapOrderError.backend(message)
        }

        guard payload.success else {
            let message = payload.message ?? "Failed to load orders."
            throw ZapOrderError.backend(message)
        }

        return payload.orders
    }

    func cancelOrder(
        orderId: String,
        userWalletAddress: String,
        reason: String? = nil
    ) async throws -> ZapOrderDTO {
        let trimmedWallet = userWalletAddress.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedWallet.isEmpty else {
            throw ZapOrderError.invalidMerchant
        }

        var url = baseURL
        url.appendPathComponent("api/zapp/orders")
        url.appendPathComponent(orderId)
        url.appendPathComponent("cancel")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ZapOrderCancelRequest(
            userWalletAddress: trimmedWallet,
            reason: reason
        )

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ZapOrderError.backend("Invalid server response.")
        }

        let decoder = JSONDecoder()
        let payload = try decoder.decode(ZapOrderCancelResponse.self, from: data)

        guard httpResponse.statusCode >= 200, httpResponse.statusCode < 300 else {
            let message = payload.message ?? "Failed to cancel order (status: \(httpResponse.statusCode))."
            throw ZapOrderError.backend(message)
        }

        guard payload.success, let order = payload.order else {
            let message = payload.message ?? "Failed to cancel order."
            throw ZapOrderError.backend(message)
        }

        return order
    }
    
    // MARK: - Batch Order Methods
    
    func createBatchOrder(
        userWalletAddress: String,
        items: [BatchOrderItem]
    ) async throws -> BatchOrderDTO {
        let trimmedWallet = userWalletAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedWallet.isEmpty else {
            throw ZapOrderError.invalidMerchant
        }
        
        guard !items.isEmpty else {
            throw ZapOrderError.backend("At least one recipient is required.")
        }
        
        var url = baseURL
        url.appendPathComponent("api/zapp/orders/batch")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let itemRequests = items.map { item in
            BatchOrderItemRequest(
                merchantCode: item.merchantCode.trimmingCharacters(in: .whitespacesAndNewlines),
                merchantName: item.merchantName?.trimmingCharacters(in: .whitespacesAndNewlines),
                fiatAmount: NSDecimalNumber(decimal: item.fiatAmount).doubleValue,
                fiatCurrency: item.fiatCurrency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                paymentRail: item.paymentRail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                scannedQRCodeData: item.scannedQRCodeData?.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        
        let body = BatchOrderCreateRequest(
            userWalletAddress: trimmedWallet,
            items: itemRequests,
            metadata: [
                "platform": "ios",
                "app": "zapp",
                "type": "batch"
            ]
        )
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ZapOrderError.backend("Invalid server response.")
        }
        
        let decoder = JSONDecoder()
        let payload = try decoder.decode(BatchOrderCreateResponse.self, from: data)
        
        guard httpResponse.statusCode >= 200, httpResponse.statusCode < 300 else {
            let message = payload.message ?? "Failed to create batch order (status: \(httpResponse.statusCode))."
            throw ZapOrderError.backend(message)
        }
        
        guard payload.success, let batchOrder = payload.batchOrder else {
            let message = payload.message ?? "Failed to create batch order."
            throw ZapOrderError.backend(message)
        }
        
        return batchOrder
    }
    
    func getBatchOrder(
        batchId: String,
        userWalletAddress: String
    ) async throws -> BatchOrderDTO? {
        let trimmedWallet = userWalletAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedWallet.isEmpty else {
            throw ZapOrderError.invalidMerchant
        }
        
        var url = baseURL
        url.appendPathComponent("api/zapp/orders/batch")
        url.appendPathComponent(batchId)
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "user_wallet_address", value: trimmedWallet)]
        
        guard let finalURL = components?.url else {
            throw ZapOrderError.backend("Invalid URL.")
        }
        
        var request = URLRequest(url: finalURL)
        request.httpMethod = "GET"
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ZapOrderError.backend("Invalid server response.")
        }
        
        if httpResponse.statusCode == 404 {
            return nil
        }
        
        let decoder = JSONDecoder()
        let payload = try decoder.decode(BatchOrderGetResponse.self, from: data)
        
        guard httpResponse.statusCode >= 200, httpResponse.statusCode < 300 else {
            let message = payload.message ?? "Failed to get batch order (status: \(httpResponse.statusCode))."
            throw ZapOrderError.backend(message)
        }
        
        guard payload.success else {
            let message = payload.message ?? "Failed to get batch order."
            throw ZapOrderError.backend(message)
        }
        
        return payload.batchOrder
    }
}
