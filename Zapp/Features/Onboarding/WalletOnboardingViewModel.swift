import Foundation
import Combine

final class WalletOnboardingViewModel: ObservableObject {
    @Published var importText: String = ""
    @Published var errorMessage: String?
    @Published var didComplete: Bool = false

    private let seedStore: WalletSeedStoring
    private let metadataStore: WalletMetadataStoring

    init(
        seedStore: WalletSeedStoring = WalletSeedStore(),
        metadataStore: WalletMetadataStoring = WalletMetadataStore()
    ) {
        self.seedStore = seedStore
        self.metadataStore = metadataStore
    }

    func createNewWallet() {
        errorMessage = nil
        let seed = (0..<32).map { _ in UInt8.random(in: 0...255) }
        let mnemonic = WalletMnemonicCodec.mnemonic(fromSeed: seed)

        do {
            try seedStore.saveSeed(seed)
            try seedStore.saveMnemonic(mnemonic)
            metadataStore.saveOrigin(.new)
            metadataStore.saveCreationDateIfMissing(Date())
            didComplete = true
        } catch {
            errorMessage = "Failed to save wallet."
        }
    }

    func importWallet() {
        errorMessage = nil

        let trimmed = importText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Enter a recovery phrase or hex-encoded seed."
            return
        }

        let seed: [UInt8]
        let mnemonic: String?

        if trimmed.contains(" ") {
            guard let decoded = WalletMnemonicCodec.seed(fromMnemonic: trimmed) else {
                errorMessage = "Invalid recovery phrase."
                return
            }
            seed = decoded
            mnemonic = WalletMnemonicCodec.mnemonic(fromSeed: decoded)
        } else {
            guard let decoded = Self.hexStringToBytes(trimmed) else {
                errorMessage = "Invalid hex seed. Use only 0-9 and a-f characters."
                return
            }
            seed = decoded
            mnemonic = nil
        }

        do {
            try seedStore.saveSeed(seed)
            if let mnemonic = mnemonic {
                try seedStore.saveMnemonic(mnemonic)
            }
            didComplete = true
        } catch {
            errorMessage = "Failed to save imported wallet."
        }
    }

    private static func hexStringToBytes(_ hex: String) -> [UInt8]? {
        let cleaned = hex.lowercased()
        guard cleaned.count % 2 == 0 else { return nil }

        var bytes: [UInt8] = []
        bytes.reserveCapacity(cleaned.count / 2)

        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let nextIndex = cleaned.index(index, offsetBy: 2)
            let pair = cleaned[index..<nextIndex]
            guard let value = UInt8(pair, radix: 16) else { return nil }
            bytes.append(value)
            index = nextIndex
        }
        return bytes
    }
}
