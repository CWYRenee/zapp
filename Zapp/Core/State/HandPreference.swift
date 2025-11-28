import Foundation

enum HandPreference: String, CaseIterable, Identifiable {
    case right
    case left

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .right:
            return "Right-handed"
        case .left:
            return "Left-handed"
        }
    }
}
