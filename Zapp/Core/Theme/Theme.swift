import SwiftUI

enum ZapColors {
    /// Primary brand color: Orange #FF9417
    static let primary = Color(red: 1.0, green: 0.58, blue: 0.09)
    static let background = Color(.systemBackground)
    static let textPrimary = Color(.label)
    static let textSecondary = Color(.secondaryLabel)
    /// Accent color: lighter orange tint
    static let accent = Color(red: 1.0, green: 0.72, blue: 0.4)
}

enum ZapSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let base: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
}

enum ZapRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
}

enum ZapTypography {
    static let titleFont = Font.system(size: 28, weight: .bold, design: .rounded)
    static let subtitleFont = Font.system(size: 16, weight: .regular, design: .rounded)
    static let bodyFont = Font.system(size: 16, weight: .regular, design: .default)
    static let buttonFont = Font.system(size: 16, weight: .semibold, design: .rounded)
}
