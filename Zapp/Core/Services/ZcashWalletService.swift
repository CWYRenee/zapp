import Foundation
import Combine
import ZcashLightClientKit

struct WalletInfo {
	let unifiedAddress: String
	let transparentAddress: String
	let shieldedBalance: Zatoshi
	let shieldedSpendable: Zatoshi
	let transparentBalance: Zatoshi

	var totalBalance: Zatoshi { shieldedBalance + transparentBalance }
	var verifiedBalance: Zatoshi { shieldedSpendable }
	var address: String { unifiedAddress }
}

struct WalletTransactionsPage {
	let page: Int
	let pageCount: Int
	let items: [ZcashTransaction.Overview]
}

protocol WalletServicing {
	func initializeWalletIfNeeded() async throws -> WalletInfo
	var syncStatePublisher: AnyPublisher<WalletSyncState, Never> { get }
	func resetWallet() async throws
	func loadTransactionsPage(page: Int) async throws -> WalletTransactionsPage
	func loadMemos(for rawID: Data) async throws -> [Memo]
	func send(to address: String, amount: String, memo: String?) async throws -> Data
	func shieldTransparentFunds() async throws
}

enum WalletError: Error, LocalizedError {
	case initializationFailed
	case invalidRecipient
	case invalidAmount
	case syncNotReady
	case sendFailed(String)

	var errorDescription: String? {
		switch self {
		case .initializationFailed:
			return "Unable to initialize wallet."
		case .invalidRecipient:
			return "Invalid recipient address."
		case .invalidAmount:
			return "Invalid amount."
		case .syncNotReady:
			return "Wallet is not synced yet. Please wait for sync to complete before sending."
		case .sendFailed(let message):
			return "Send failed: \(message)"
		}
	}
}

final class ZcashWalletService: WalletServicing {
	private var config: ZcashWalletConfig?
	private let seedStore: WalletSeedStoring
	private var cachedWallet: WalletInfo?
	private var initializer: Initializer?
	private var synchronizer: Synchronizer?
	private var cancellables: Set<AnyCancellable> = []
	private let syncStateSubject = CurrentValueSubject<WalletSyncState, Never>(.initial)

	var syncStatePublisher: AnyPublisher<WalletSyncState, Never> {
		syncStateSubject.eraseToAnyPublisher()
	}

	init(seedStore: WalletSeedStoring = WalletSeedStore()) {
		self.seedStore = seedStore
	}

	func initializeWalletIfNeeded() async throws -> WalletInfo {
		let config: ZcashWalletConfig
		if let existing = self.config {
			config = existing
		} else {
			guard let seed = seedStore.loadSeed() else {
				throw WalletError.initializationFailed
			}
			config = ZcashWalletConfig.fromSeed(seed)
			self.config = config
		}

		let initializer: Initializer
		if let existing = self.initializer {
			initializer = existing
		} else {
			initializer = try config.makeInitializer()
			self.initializer = initializer
		}

		let synchronizer: Synchronizer
		if let existingSync = self.synchronizer {
			synchronizer = existingSync
		} else {
			let sdkSynchronizer = SDKSynchronizer(initializer: initializer)
			self.synchronizer = sdkSynchronizer
			synchronizer = sdkSynchronizer
			bindSyncState(from: sdkSynchronizer)
		}

		if case .unprepared = synchronizer.latestState.syncStatus {
			_ = try await synchronizer.prepare(
				with: config.seed,
				walletBirthday: config.birthday,
				for: .existingWallet,
				name: "",
				keySource: nil
			)
		}

		// Start or resume sync. This mirrors the Example app's behaviour where start is
		// called whenever the synchronizer is not actively syncing.
		switch synchronizer.latestState.syncStatus {
		case .syncing:
			break
		case .unprepared, .upToDate, .stopped, .error:
			try await synchronizer.start(retry: false)
		}

		guard let account = try await synchronizer.listAccounts().first else {
			throw WalletError.initializationFailed
		}

		guard let unifiedAddress = try? await synchronizer.getUnifiedAddress(accountUUID: account.id) else {
			throw WalletError.initializationFailed
		}

		let transparentAddress = (try? await synchronizer.getTransparentAddress(accountUUID: account.id))?.stringEncoded ?? ""

		// Try to fetch balances, but don't fail wallet initialization if this
		// step has an issue. Falling back to .zero matches the sample app's
		// behavior and avoids blocking the UI on balance fetch.
		let shieldedBalance: Zatoshi
		let shieldedSpendable: Zatoshi
		let transparentBalance: Zatoshi
		if let balances = try? await synchronizer.getAccountsBalances(),
		   let accountBalance = balances[account.id] {
			let sapling = accountBalance.saplingBalance
			let orchard = accountBalance.orchardBalance
			shieldedBalance = sapling.total() + orchard.total()
			shieldedSpendable = sapling.spendableValue + orchard.spendableValue
			transparentBalance = accountBalance.unshielded
		} else {
			shieldedBalance = .zero
			shieldedSpendable = .zero
			transparentBalance = .zero
		}

		let wallet = WalletInfo(
			unifiedAddress: unifiedAddress.stringEncoded,
			transparentAddress: transparentAddress,
			shieldedBalance: shieldedBalance,
			shieldedSpendable: shieldedSpendable,
			transparentBalance: transparentBalance
		)
		cachedWallet = wallet
		return wallet
	}

	func loadTransactionsPage(page: Int) async throws -> WalletTransactionsPage {
		_ = try await initializeWalletIfNeeded()
		guard let synchronizer = self.synchronizer else {
			throw WalletError.initializationFailed
		}

		let repository = synchronizer.paginatedTransactions(of: .all)
		let transactions = try await repository.page(page) ?? []
		let pageCount = await repository.pageCount

		return WalletTransactionsPage(page: page, pageCount: pageCount, items: transactions)
	}

	func loadMemos(for rawID: Data) async throws -> [Memo] {
		_ = try await initializeWalletIfNeeded()
		guard let synchronizer = self.synchronizer else {
			throw WalletError.initializationFailed
		}

		return try await synchronizer.getMemos(for: rawID)
	}

	func send(to address: String, amount: String, memo: String?) async throws -> Data {
		_ = try await initializeWalletIfNeeded()
		guard
			let synchronizer = self.synchronizer,
			let config = self.config
		else {
			throw WalletError.initializationFailed
		}

		// Require wallet to be fully synced before sending.
		switch synchronizer.latestState.syncStatus {
		case .upToDate:
			break
		case .syncing(_, let areFundsSpendable) where areFundsSpendable:
			break
		default:
			throw WalletError.syncNotReady
		}

		guard let account = try await synchronizer.listAccounts().first else {
			throw WalletError.initializationFailed
		}

		// Parse amount as Zatoshi from a decimal ZEC string.
		guard let zatoshi = Zatoshi.from(decimalString: amount) else {
			throw WalletError.invalidAmount
		}

		// Normalize address (supports plain addresses and zcash: URIs) and
		// build recipient for the current network.
		let normalizedAddress = normalizeRecipientAddress(address)
		let recipient: Recipient
		do {
			recipient = try Recipient(normalizedAddress, network: config.network.networkType)
		} catch {
			throw WalletError.invalidRecipient
		}

		// Optional memo. The SDK does not allow memos on transparent addresses, so
		// explicitly drop the memo in that case to avoid low-level ZcashError
		// failures.
		let memoValue: Memo?
		if case .transparent = recipient {
			memoValue = nil
		} else if let memoText = memo, !memoText.isEmpty {
			do {
				memoValue = try Memo(string: memoText)
			} catch {
				throw WalletError.sendFailed("Invalid memo: \(error.localizedDescription)")
			}
		} else {
			memoValue = nil
		}

		// Create proposal.
		let proposal: Proposal
		do {
			proposal = try await synchronizer.proposeTransfer(
				accountUUID: account.id,
				recipient: recipient,
				amount: zatoshi,
				memo: memoValue
			)
		} catch let zcashError as ZcashError {
			let message: String
			if case let .rustCreateToAddress(rustMessage) = zcashError {
				message = rustMessage
			} else {
				message = zcashError.message
			}
			throw WalletError.sendFailed(message)
		} catch {
			throw WalletError.sendFailed(error.localizedDescription)
		}

		// Derive UnifiedSpendingKey from the stored seed for account 0.
		let derivationTool = DerivationTool(networkType: config.network.networkType)
		let usk: UnifiedSpendingKey
		do {
			usk = try derivationTool.deriveUnifiedSpendingKey(
				seed: config.seed,
				accountIndex: Zip32AccountIndex(0)
			)
		} catch {
			throw WalletError.sendFailed("Unable to derive spending key.")
		}

		// Create and submit transactions for the proposal.
		let stream: AsyncThrowingStream<TransactionSubmitResult, Error>
		do {
			stream = try await synchronizer.createProposedTransactions(
				proposal: proposal,
				spendingKey: usk
			)
		} catch let zcashError as ZcashError {
			let message: String
			if case let .rustCreateToAddress(rustMessage) = zcashError {
				message = rustMessage
			} else {
				message = zcashError.message
			}
			throw WalletError.sendFailed(message)
		} catch {
			throw WalletError.sendFailed(error.localizedDescription)
		}

		var lastResult: TransactionSubmitResult?
		do {
			for try await result in stream {
				lastResult = result
			}
		} catch {
			throw WalletError.sendFailed(error.localizedDescription)
		}

		guard let finalResult = lastResult else {
			throw WalletError.sendFailed("No submission result returned.")
		}

		switch finalResult {
		case .success(let txId):
			return txId
		case .grpcFailure(_, let error):
			throw WalletError.sendFailed(String(describing: error))
		case .submitFailure(_, _, let description):
			throw WalletError.sendFailed(description)
		case .notAttempted:
			throw WalletError.sendFailed("Transaction was created but not submitted.")
		}
	}

	func shieldTransparentFunds() async throws {
		_ = try await initializeWalletIfNeeded()
		guard
			let synchronizer = self.synchronizer,
			let config = self.config
		else {
			throw WalletError.initializationFailed
		}

		guard let account = try await synchronizer.listAccounts().first else {
			throw WalletError.initializationFailed
		}

		// Check current transparent balance and exit early if there's nothing to shield.
		if let balances = try? await synchronizer.getAccountsBalances(),
		   let accountBalance = balances[account.id] {
			let transparent = accountBalance.unshielded
			guard transparent > .zero else { return }
		} else {
			return
		}

		// Require wallet to be sufficiently synced before shielding (same policy as send).
		switch synchronizer.latestState.syncStatus {
		case .upToDate:
			break
		case .syncing(_, let areFundsSpendable) where areFundsSpendable:
			break
		default:
			throw WalletError.syncNotReady
		}

		let memo: Memo
		do {
			memo = try Memo(string: "Shield transparent funds")
		} catch {
			throw WalletError.sendFailed("Unable to create shielding memo.")
		}

		guard let proposal = try await synchronizer.proposeShielding(
			accountUUID: account.id,
			shieldingThreshold: .zero,
			memo: memo,
			transparentReceiver: nil
		) else {
			// Nothing to shield (e.g. below threshold)
			return
		}

		// Derive UnifiedSpendingKey from the stored seed for account 0.
		let derivationTool = DerivationTool(networkType: config.network.networkType)
		let usk: UnifiedSpendingKey
		do {
			usk = try derivationTool.deriveUnifiedSpendingKey(
				seed: config.seed,
				accountIndex: Zip32AccountIndex(0)
			)
		} catch {
			throw WalletError.sendFailed("Unable to derive spending key.")
		}

		let stream = try await synchronizer.createProposedTransactions(
			proposal: proposal,
			spendingKey: usk
		)

		var lastResult: TransactionSubmitResult?
		do {
			for try await result in stream {
				lastResult = result
			}
		} catch {
			throw WalletError.sendFailed(error.localizedDescription)
		}

		guard let finalResult = lastResult else {
			throw WalletError.sendFailed("Shielding transaction was created but not submitted.")
		}

		switch finalResult {
		case .success:
			return
		case .grpcFailure(_, let error):
			throw WalletError.sendFailed(String(describing: error))
		case .submitFailure(_, _, let description):
			throw WalletError.sendFailed(description)
		case .notAttempted:
			throw WalletError.sendFailed("Shielding transaction was created but not submitted.")
		}
	}

	func resetWallet() async throws {
		try await wipeSynchronizerIfNeeded()
		try seedStore.clear()
		config = nil
		cachedWallet = nil
		initializer = nil
		synchronizer = nil
		syncStateSubject.send(.initial)
	}

	private func normalizeRecipientAddress(_ address: String) -> String {
		let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)

		guard
			let url = URL(string: trimmed),
			let scheme = url.scheme?.lowercased(),
			scheme.hasPrefix("zcash")
		else {
			return trimmed
		}

		if let host = url.host, !host.isEmpty {
			return host
		}

		let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
		if !path.isEmpty {
			return path
		}

		if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
		   let queryItems = components.queryItems,
		   let addressItem = queryItems.first(where: { $0.name == "address" }),
		   let value = addressItem.value,
		   !value.isEmpty {
			return value
		}

		return trimmed
	}

	private func bindSyncState(from synchronizer: Synchronizer) {
		synchronizer.stateStream
			.throttle(for: .seconds(0.3), scheduler: DispatchQueue.main, latest: true)
			.sink { [weak self] state in
				self?.syncStateSubject.send(Self.makeSyncState(from: state.syncStatus))
			}
			.store(in: &cancellables)
	}

	private func wipeSynchronizerIfNeeded() async throws {
		guard let synchronizer = synchronizer else { return }

		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
			var cancellable: AnyCancellable?
			cancellable = synchronizer
				.wipe()
				.sink(
					receiveCompletion: { completion in
						switch completion {
						case .finished:
							continuation.resume()
						case let .failure(error):
							continuation.resume(throwing: error)
						}
						cancellable?.cancel()
						cancellable = nil
					},
					receiveValue: { _ in }
				)
		}
	}

	private static func makeSyncState(from status: SyncStatus) -> WalletSyncState {
		switch status {
		case let .syncing(progress, areFundsSpendable):
			let progressDouble = Double(progress)
			let percent = floor(progressDouble * 1000) / 1000
			let text = "Syncing \(Int(percent * 100))% • spendable: \(areFundsSpendable)"
			return WalletSyncState(statusText: text, progress: progressDouble, isSynced: false, areFundsSpendable: areFundsSpendable)
		case .upToDate:
			return WalletSyncState(statusText: "Up to date", progress: 1.0, isSynced: true, areFundsSpendable: true)
		case .unprepared:
			return WalletSyncState(statusText: "Unprepared", progress: 0.0, isSynced: false, areFundsSpendable: false)
		case .stopped:
			return WalletSyncState(statusText: "Stopped", progress: 0.0, isSynced: false, areFundsSpendable: false)
		case .error:
			return WalletSyncState(statusText: "Error", progress: 0.0, isSynced: false, areFundsSpendable: false)
		}
	}
}
