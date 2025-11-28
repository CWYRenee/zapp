import Foundation

protocol WalletSeedStoring {
    func loadSeed() -> [UInt8]?
    func saveSeed(_ seed: [UInt8]) throws

    func loadMnemonic() -> String?
    func saveMnemonic(_ mnemonic: String) throws

    func clear() throws
}

enum WalletSeedStoreError: Error {
    case failedToSave
}

final class WalletSeedStore: WalletSeedStoring {
    private let seedKey = "zapp.wallet.seed"
    private let mnemonicKey = "zapp.wallet.mnemonic"

    func loadSeed() -> [UInt8]? {
        guard let data = UserDefaults.standard.data(forKey: seedKey) else { return nil }
        return [UInt8](data)
    }

    func saveSeed(_ seed: [UInt8]) throws {
        let data = Data(seed)
        UserDefaults.standard.set(data, forKey: seedKey)
        // UserDefaults.set is not failable, but we keep the signature throwable
        // in case we later switch to a different storage mechanism.
    }

    func loadMnemonic() -> String? {
        UserDefaults.standard.string(forKey: mnemonicKey)
    }

    func saveMnemonic(_ mnemonic: String) throws {
        UserDefaults.standard.set(mnemonic, forKey: mnemonicKey)
    }

    func clear() throws {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: seedKey)
        defaults.removeObject(forKey: mnemonicKey)
    }
}
