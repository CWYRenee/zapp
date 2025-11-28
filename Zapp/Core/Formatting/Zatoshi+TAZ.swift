import Foundation
import ZcashLightClientKit

extension Zatoshi {
    private static let tazFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 4
        formatter.maximumFractionDigits = 4
        formatter.usesGroupingSeparator = true
        return formatter
    }()

    func tazString(abs: Bool = false) -> String {
        let value = abs ? Zatoshi(Swift.abs(amount)) : self
        return value.decimalString(formatter: Zatoshi.tazFormatter)
    }
}
