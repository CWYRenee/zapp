import Foundation
import ZcashLightClientKit

struct ZcashWalletConfig {
    let network: ZcashNetwork
    let endpoint: LightWalletEndpoint
    let seed: [UInt8]

    init(
        network: ZcashNetwork,
        endpoint: LightWalletEndpoint,
        seed: [UInt8]
    ) {
        self.network = network
        self.endpoint = endpoint
        self.seed = seed
    }

    static func fromSeed(_ seed: [UInt8]) -> ZcashWalletConfig {
        let network = ZcashNetworkBuilder.network(for: .testnet)
        let endpoint = LightWalletEndpoint(
            address: "lightwalletd.testnet.electriccoin.co",
            port: 9067,
            secure: true,
            streamingCallTimeoutInMillis: 10 * 60 * 60 * 1000
        )

        return ZcashWalletConfig(
            network: network,
            endpoint: endpoint,
            seed: seed
        )
    }

    func makeInitializer() throws -> Initializer {
        let documentsDirectory = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let chainFolder = documentsDirectory
            .appendingPathComponent(network.networkType.chainName, isDirectory: true)

        let fsBlockDbRoot = chainFolder
            .appendingPathComponent(ZcashSDK.defaultFsCacheName, isDirectory: true)

        let generalStorageURL = chainFolder
            .appendingPathComponent("general_storage", isDirectory: true)

        let dataDbURL = documentsDirectory
            .appendingPathComponent(
                network.constants.defaultDbNamePrefix + ZcashSDK.defaultDataDbName,
                isDirectory: false
            )

        let cacheDbURL = documentsDirectory
            .appendingPathComponent(
                network.constants.defaultDbNamePrefix + ZcashSDK.defaultCacheDbName,
                isDirectory: false
            )

        let torDirURL = chainFolder
            .appendingPathComponent(ZcashSDK.defaultTorDirName, isDirectory: true)

        let spendParamsURL = documentsDirectory
            .appendingPathComponent("sapling-spend.params", isDirectory: false)

        let outputParamsURL = documentsDirectory
            .appendingPathComponent("sapling-output.params", isDirectory: false)

        return Initializer(
            cacheDbURL: cacheDbURL,
            fsBlockDbRoot: fsBlockDbRoot,
            generalStorageURL: generalStorageURL,
            dataDbURL: dataDbURL,
            torDirURL: torDirURL,
            endpoint: endpoint,
            network: network,
            spendParamsURL: spendParamsURL,
            outputParamsURL: outputParamsURL,
            saplingParamsSourceURL: SaplingParamsSourceURL.default,
            isTorEnabled: false,
            isExchangeRateEnabled: false
        )
    }
}
