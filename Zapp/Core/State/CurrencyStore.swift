import SwiftUI
import Combine

enum Currency: String, CaseIterable, Identifiable {
    case usd = "USD"
    case inr = "INR"
    case cny = "CNY"
    case brl = "BRL"
    case eur = "EUR"
    case gbp = "GBP"
    case jpy = "JPY"
    case krw = "KRW"
    case thb = "THB"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .usd: return "$"
        case .inr: return "₹"
        case .cny, .jpy: return "¥"
        case .brl: return "R$"
        case .eur: return "€"
        case .gbp: return "£"
        case .krw: return "₩"
        case .thb: return "฿"
        }
    }

    var name: String {
        switch self {
        case .usd: return "US Dollar"
        case .inr: return "Indian Rupee"
        case .cny: return "Chinese Yuan"
        case .brl: return "Brazilian Real"
        case .eur: return "Euro"
        case .gbp: return "British Pound"
        case .jpy: return "Japanese Yen"
        case .krw: return "South Korean Won"
        case .thb: return "Thai Baht"
        }
    }
}

@MainActor
class CurrencyStore: ObservableObject {
    @AppStorage("selectedCurrency") var selectedCurrency: Currency = .inr
    @Published var rates: [String: Double] = [:]
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    init() {
        // Load initial rates if possible or wait for task
    }

    func fetchRates() async {
        guard rates.isEmpty else { return } // Simple cache
        isLoading = true
        errorMessage = nil

        do {
            // Using open.er-api.com for free rates (USD base)
            let url = URL(string: "https://open.er-api.com/v6/latest/USD")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(ExchangeRateResponse.self, from: data)
            self.rates = response.rates
        } catch {
            errorMessage = "Failed to load rates: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func convert(_ usdAmount: Decimal) -> String {
        let rate = Decimal(rates[selectedCurrency.rawValue] ?? 1.0)
        // If USD is selected, rate is 1.0 (or should be in the map)
        // If rates are missing and currency is not USD, we might show USD or loading
        
        let converted = usdAmount * rate
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = selectedCurrency.rawValue
        formatter.currencySymbol = selectedCurrency.symbol
        formatter.maximumFractionDigits = 2
        
        return formatter.string(from: NSDecimalNumber(decimal: converted)) ?? "\(selectedCurrency.symbol)0.00"
    }

    /// Returns the rate for USD -> Selected Currency
    var currentRate: Decimal {
        Decimal(rates[selectedCurrency.rawValue] ?? 1.0)
    }

    func convert(amount: Decimal, from sourceCurrencyCode: String, to targetCurrency: Currency) -> Decimal {
        guard let sourceRate = rates[sourceCurrencyCode], let targetRate = rates[targetCurrency.rawValue] else {
            // Fallback: if source is USD, we might have target rate.
            if sourceCurrencyCode == "USD", let targetRate = rates[targetCurrency.rawValue] {
                return amount * Decimal(targetRate)
            }
            // If target is USD, we might have source rate.
            if targetCurrency == .usd, let sourceRate = rates[sourceCurrencyCode] {
                return amount / Decimal(sourceRate)
            }
            return amount // Failed to convert
        }
        
        // Convert source to USD: Amount / Rate(USD->Source)
        // Convert USD to target: AmountInUSD * Rate(USD->Target)
        let amountInUsd = amount / Decimal(sourceRate)
        let amountInTarget = amountInUsd * Decimal(targetRate)
        return amountInTarget
    }
}

struct ExchangeRateResponse: Decodable {
    let rates: [String: Double]
}
