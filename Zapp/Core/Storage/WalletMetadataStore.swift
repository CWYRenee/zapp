import Foundation

enum WalletOrigin: String {
    case new
    case restored
}

protocol WalletMetadataStoring {
    func loadOrigin() -> WalletOrigin?
    func saveOrigin(_ origin: WalletOrigin)
    func loadCreationDate() -> Date?
    func saveCreationDateIfMissing(_ date: Date)
    func clear()
}

final class WalletMetadataStore: WalletMetadataStoring {
    private let originKey = "zapp.wallet.origin"
    private let createdAtKey = "zapp.wallet.createdAt"

    func loadOrigin() -> WalletOrigin? {
        guard let raw = UserDefaults.standard.string(forKey: originKey) else { return nil }
        return WalletOrigin(rawValue: raw)
    }

    func saveOrigin(_ origin: WalletOrigin) {
        UserDefaults.standard.set(origin.rawValue, forKey: originKey)
    }

    func loadCreationDate() -> Date? {
        UserDefaults.standard.object(forKey: createdAtKey) as? Date
    }

    func saveCreationDateIfMissing(_ date: Date) {
        guard loadCreationDate() == nil else { return }
        UserDefaults.standard.set(date, forKey: createdAtKey)
    }

    func clear() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: originKey)
        defaults.removeObject(forKey: createdAtKey)
    }
}
