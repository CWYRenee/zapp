import SwiftUI
import Combine
import UIKit
import AVFoundation
import LocalAuthentication

struct SendView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var walletViewModel: WalletViewModel
    @EnvironmentObject private var currencyStore: CurrencyStore

    // MARK: - Send Mode Selection
    enum SendMode: String, CaseIterable, Identifiable {
        case onchain
        case offchain
        
        var id: String { rawValue }
        
        var title: String {
            switch self {
            case .onchain: return "Onchain"
            case .offchain: return "Offchain"
            }
        }
        
        var description: String {
            switch self {
            case .onchain: return "Send ZEC to a Zcash address"
            case .offchain: return "Send to payment apps (UPI, Alipay, etc.)"
            }
        }
    }
    
    @State private var sendMode: SendMode = .onchain

    // MARK: - Source Address Selection
    enum SendAddressType: String, CaseIterable, Identifiable {
        case unified
        case transparent
        
        var id: String { rawValue }
        
        var title: String {
            switch self {
            case .unified: return "Unified"
            case .transparent: return "Transparent"
            }
        }
    }
    
    // MARK: - Amount Input Mode
    enum AmountInputMode: String, CaseIterable {
        case zec
        case fiat
        
        var title: String {
            switch self {
            case .zec: return "ZEC"
            case .fiat: return "Fiat"
            }
        }
    }

    @State private var toAddress: String = ""
    @State private var amount: String = ""
    @State private var note: String = ""
    @State private var isSending: Bool = false
    @State private var errorMessage: String?
    @State private var isShowingQRScanner: Bool = false
    @State private var availableTokens: [SwapKitToken] = []
    @State private var isLoadingTokens: Bool = false
    @State private var isShowingTokenSelector: Bool = false
    @State private var tokenSearchText: String = ""
    @State private var selectedToken: SwapKitToken?
    
    // Source address selection (default to unified)
    @State private var selectedSourceAddressType: SendAddressType = .unified
    
    // Amount input mode and ZEC price
    @State private var amountInputMode: AmountInputMode = .zec
    @State private var zecPriceUsd: Double?
    @State private var isLoadingZecPrice: Bool = false
    
    // Biometric authentication
    private let biometricService = BiometricAuthService.shared
    private let biometricSettings = BiometricSettingsStore.shared

    private var maxSendableAmountText: String? {
        guard let info = walletViewModel.walletInfo else { return nil }
        return info.shieldedSpendable.tazString()
    }
    
    /// Returns the source address based on user selection
    private var sourceAddress: String {
        guard let info = walletViewModel.walletInfo else { return "No address yet" }
        switch selectedSourceAddressType {
        case .unified:
            return info.unifiedAddress
        case .transparent:
            return info.transparentAddress.isEmpty ? "No address yet" : info.transparentAddress
        }
    }
    
    /// Converts the input amount to ZEC based on the current input mode
    private var zecAmount: String {
        let trimmed = amount.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        
        switch amountInputMode {
        case .zec:
            return trimmed
        case .fiat:
            guard let fiatValue = Decimal(string: trimmed),
                  let priceUsd = zecPriceUsd,
                  priceUsd > 0 else {
                return ""
            }
            
            let priceDecimal = Decimal(priceUsd)
            let rate = currencyStore.convert(amount: 1, from: "USD", to: currencyStore.selectedCurrency)
            let zecPriceInSelected = priceDecimal * rate
            
            guard zecPriceInSelected > 0 else { return "" }
            
            let zecDecimal = fiatValue / zecPriceInSelected
            
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 8
            formatter.minimumFractionDigits = 2
            formatter.groupingSeparator = ""
            
            return formatter.string(from: NSDecimalNumber(decimal: zecDecimal)) ?? ""
        }
    }
    
    /// Shows the converted amount in the alternate currency
    private var convertedAmountText: String? {
        let trimmed = amount.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let inputValue = Decimal(string: trimmed),
              let priceUsd = zecPriceUsd,
              priceUsd > 0 else {
            return nil
        }
        
        let priceDecimal = Decimal(priceUsd)
        let rate = currencyStore.convert(amount: 1, from: "USD", to: currencyStore.selectedCurrency)
        let zecPriceInSelected = priceDecimal * rate
        
        guard zecPriceInSelected > 0 else { return nil }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        
        switch amountInputMode {
        case .zec:
            // Convert ZEC to fiat
            let fiatValue = inputValue * zecPriceInSelected
            formatter.maximumFractionDigits = 2
            if let formatted = formatter.string(from: NSDecimalNumber(decimal: fiatValue)) {
                return "≈ \(currencyStore.selectedCurrency.symbol)\(formatted)"
            }
        case .fiat:
            // Convert fiat to ZEC
            let zecValue = inputValue / zecPriceInSelected
            formatter.maximumFractionDigits = 8
            if let formatted = formatter.string(from: NSDecimalNumber(decimal: zecValue)) {
                return "≈ \(formatted) ZEC"
            }
        }
        
        return nil
    }

    private var normalizedAddress: String {
        toAddress.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedAmount: String {
        amount.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isFormDisabled: Bool {
        isSending
            || normalizedAddress.isEmpty
            || normalizedAmount.isEmpty
            || !walletViewModel.isReadyToSpend
    }
    
    /// Validates if the address is a recognized format
    private var addressValidation: AddressValidationResult {
        let addr = normalizedAddress
        guard !addr.isEmpty else { return .empty }
        
        // Unified address (starts with "u1" for mainnet or "utest1" for testnet)
        if addr.hasPrefix("u1") || addr.hasPrefix("utest1") {
            return .valid(.unified)
        }
        
        // Transparent address (starts with "t1" or "t3" for mainnet, or "tm" for testnet)
        if addr.hasPrefix("t1") || addr.hasPrefix("t3") || addr.hasPrefix("tm") {
            return .valid(.transparent)
        }
        
        // Sapling shielded address (starts with "zs" for mainnet or "ztestsapling" for testnet)
        if addr.hasPrefix("zs") || addr.hasPrefix("ztestsapling") {
            return .valid(.sapling)
        }
        
        // EVM address (starts with "0x" and is 42 characters)
        if addr.hasPrefix("0x") && addr.count == 42 {
            // Basic hex validation
            let hexPart = String(addr.dropFirst(2))
            let isValidHex = hexPart.allSatisfy { $0.isHexDigit }
            if isValidHex {
                return .valid(.evm)
            }
        }
        
        return .invalid
    }
    
    private enum AddressType {
        case unified
        case transparent
        case sapling
        case evm
        
        var description: String {
            switch self {
            case .unified: return "Unified address"
            case .transparent: return "Transparent address"
            case .sapling: return "Sapling shielded address"
            case .evm: return "EVM address (cross-chain)"
            }
        }
    }
    
    private enum AddressValidationResult {
        case empty
        case valid(AddressType)
        case invalid
    }

    var body: some View {
        NavigationView {
            Group {
                if sendMode == .offchain {
                    OffchainSendView()
                } else {
                    onchainSendContent
                }
            }
            .background(ZapColors.background.ignoresSafeArea())
            .navigationTitle("Send")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Send Mode", selection: $sendMode) {
                        ForEach(SendMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
            }
        }
    }
    
    // MARK: - Onchain Send Content
    
    private var onchainSendContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: ZapSpacing.lg) {
                    // Header
                    VStack(alignment: .leading, spacing: ZapSpacing.xs) {
                        Text("Send Onchain")
                            .font(ZapTypography.titleFont)
                            .foregroundColor(ZapColors.primary)
                        
                        Text("Send ZEC directly to a Zcash address or cross-chain to other networks.")
                            .font(.footnote)
                            .foregroundColor(ZapColors.textSecondary)
                    }
                    
                    // From section with address type picker
                    VStack(alignment: .leading, spacing: ZapSpacing.sm) {
                        Text("From")
                            .font(.subheadline)
                            .foregroundColor(ZapColors.textSecondary)
                            
                            Picker("Address Type", selection: $selectedSourceAddressType) {
                                ForEach(SendAddressType.allCases) { type in
                                    Text(type.title).tag(type)
                                }
                            }
                            .pickerStyle(.segmented)
                            
                            Text(sourceAddress)
                                .font(.footnote)
                                .foregroundColor(ZapColors.textPrimary)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(ZapRadius.medium)
                        }

                        // To section
                        VStack(alignment: .leading, spacing: ZapSpacing.sm) {
                            Text("To")
                                .font(.subheadline)
                                .foregroundColor(ZapColors.textSecondary)
                            HStack(spacing: 8) {
                                TextField("Recipient address", text: $toAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)
                                Button {
                                    isShowingQRScanner = true
                                } label: {
                                    Image(systemName: "qrcode.viewfinder")
                                        .foregroundColor(ZapColors.primary)
                                }
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(ZapRadius.medium)
                            
                            // Address validation feedback
                            switch addressValidation {
                            case .empty:
                                EmptyView()
                            case .valid(let addressType):
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.footnote)
                                    Text(addressType.description)
                                        .font(.footnote)
                                        .foregroundColor(ZapColors.textSecondary)
                                }
                            case .invalid:
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .font(.footnote)
                                    Text("Unrecognized address format. Expected: Zcash unified (u1/utest1), transparent (t1/t3/tm), sapling (zs), or EVM (0x).")
                                        .font(.footnote)
                                        .foregroundColor(.orange)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: ZapSpacing.sm) {
                            Text("Asset")
                                .font(.subheadline)
                                .foregroundColor(ZapColors.textSecondary)

                            Button {
                                isShowingTokenSelector = true
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: ZapSpacing.xs) {
                                        Text(selectedToken?.ticker ?? "Zcash (local send)")
                                            .font(.body)
                                            .foregroundColor(ZapColors.textPrimary)

                                        if let token = selectedToken {
                                            Text((token.name ?? token.ticker ?? token.symbol ?? token.identifier) + " • " + token.chain)
                                                .font(.footnote)
                                                .foregroundColor(ZapColors.textSecondary)
                                        } else {
                                            Text("Send ZEC on Zcash. Select another asset for cross-chain.")
                                                .font(.footnote)
                                                .foregroundColor(ZapColors.textSecondary)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(ZapRadius.medium)
                            }
                            .buttonStyle(.plain)
                        }

                        // Amount section with ZEC/Fiat toggle
                        VStack(alignment: .leading, spacing: ZapSpacing.sm) {
                            HStack {
                                Text("Amount")
                                    .font(.subheadline)
                                    .foregroundColor(ZapColors.textSecondary)
                                
                                Spacer()
                                
                                // ZEC/Fiat toggle button
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        // Clear amount when switching modes to avoid confusion
                                        amount = ""
                                        amountInputMode = amountInputMode == .zec ? .fiat : .zec
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.left.arrow.right")
                                            .font(.caption)
                                        Text(amountInputMode == .zec ? currencyStore.selectedCurrency.rawValue : "ZEC")
                                            .font(.caption)
                                    }
                                    .foregroundColor(ZapColors.primary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(ZapColors.primary.opacity(0.1))
                                    .cornerRadius(ZapRadius.small)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            HStack(spacing: 0) {
                                // Currency/ZEC indicator
                                Text(amountInputMode == .zec ? "ZEC" : currencyStore.selectedCurrency.symbol)
                                    .font(.headline)
                                    .foregroundColor(ZapColors.textPrimary)
                                    .padding(.leading, ZapSpacing.base)
                                    .padding(.trailing, ZapSpacing.xs)
                                
                                TextField(amountInputMode == .zec ? "0.00000000" : "0.00", text: $amount)
                                    .keyboardType(.decimalPad)
                                    .padding(.vertical, 12)
                                    .padding(.trailing, ZapSpacing.xs)

                                Button("Max") {
                                    if amountInputMode == .zec, let max = maxSendableAmountText {
                                        amount = max
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .font(.subheadline)
                                .foregroundColor(amountInputMode == .zec ? ZapColors.primary : ZapColors.textSecondary)
                                .disabled(amountInputMode == .fiat)
                            }
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(ZapRadius.medium)
                            
                            // Converted amount display
                            if let converted = convertedAmountText {
                                Text(converted)
                                    .font(.footnote)
                                    .foregroundColor(ZapColors.textSecondary)
                            }

                            Text("Available: \(walletViewModel.spendableZecBalanceText)")
                                .font(.footnote)
                                .foregroundColor(ZapColors.textSecondary)
                        }

                        // Note section
                        VStack(alignment: .leading, spacing: ZapSpacing.sm) {
                            Text("Note")
                                .font(.subheadline)
                                .foregroundColor(ZapColors.textSecondary)
                            TextField("Note (optional)", text: $note)
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(ZapRadius.medium)
                            Text("Optional memo attached to this transaction.")
                                .font(.footnote)
                                .foregroundColor(ZapColors.textSecondary)
                        }
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.footnote)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal, ZapSpacing.xl)
                    .padding(.top, ZapSpacing.base)
                    .padding(.bottom, ZapSpacing.lg)
                }
                
                ZapBottomBar(
                    primaryTitle: "Send",
                    isPrimaryLoading: isSending,
                    isPrimaryDisabled: isFormDisabled,
                    onBack: {
                        dismiss()
                    },
                    onPrimary: {
                        Task { await send() }
                    }
                )
                .padding(.horizontal, ZapSpacing.xl)
                .padding(.bottom, ZapSpacing.base)
        }
        .task {
            await loadZecPriceIfNeeded()
        }
        .sheet(isPresented: $isShowingQRScanner) {
            NavigationView {
                QRCodeScannerView(
                    onCodeScanned: { code in
                        toAddress = code.trimmingCharacters(in: .whitespacesAndNewlines)
                        isShowingQRScanner = false
                    },
                    onCancel: {
                        isShowingQRScanner = false
                    }
                )
                .navigationTitle("Scan QR")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            isShowingQRScanner = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingTokenSelector) {
            TokenSelectorView(
                tokens: filteredTokens,
                isLoading: isLoadingTokens,
                searchText: $tokenSearchText,
                onSelect: { token in
                    selectedToken = token
                    isShowingTokenSelector = false
                },
                onDismiss: {
                    isShowingTokenSelector = false
                }
            )
            .task {
                await loadTokensIfNeeded()
            }
        }
    }

    @MainActor
    private func send() async {
        errorMessage = nil
        
        // Check if biometric authentication is required
        if biometricSettings.shouldRequireBiometric() {
            do {
                let authenticated = try await biometricService.authenticateForTransaction()
                guard authenticated else {
                    errorMessage = "Authentication required to send."
                    return
                }
            } catch let error as BiometricAuthService.BiometricError {
                switch error {
                case .userCancelled:
                    // User cancelled, just return without error message
                    return
                default:
                    errorMessage = error.errorDescription
                    return
                }
            } catch {
                errorMessage = "Authentication failed. Please try again."
                return
            }
        }
        
        isSending = true
        let memoText = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let address = normalizedAddress
        
        // Use converted ZEC amount (handles both ZEC and fiat input modes)
        let amountString = zecAmount
        
        guard !amountString.isEmpty else {
            isSending = false
            errorMessage = "Please enter a valid amount."
            return
        }

        if let token = selectedToken {
            let asset = token.identifier
            guard !asset.isEmpty else {
                isSending = false
                errorMessage = "Select an asset for cross-chain swap."
                return
            }

            guard walletViewModel.walletInfo != nil else {
                isSending = false
                errorMessage = "Wallet is not ready yet."
                return
            }

            do {
                let quote = try await SwapKitSwapService.shared.quoteZecSwap(
                    buyAsset: asset,
                    amount: amountString,
                    sourceZecAddress: sourceAddress,
                    destinationAddress: address
                )

                _ = try await walletViewModel.send(
                    to: quote.depositAddress,
                    amount: amountString,
                    memo: quote.memo
                )

                isSending = false
                dismiss()
            } catch {
                isSending = false
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }

            return
        }

        do {
            _ = try await walletViewModel.send(
                to: address,
                amount: amountString,
                memo: memoText.isEmpty ? nil : memoText
            )
            isSending = false
            dismiss()
        } catch {
            isSending = false
            if let walletError = error as? WalletError, case .invalidRecipient = walletError {
                errorMessage = "Destination is not a valid Zcash address for this wallet. Enter a valid unified, shielded, or transparent Zcash address on the same network, or select an asset for a cross-chain swap."
            } else {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
    
    @MainActor
    private func loadZecPriceIfNeeded() async {
        if isLoadingZecPrice || zecPriceUsd != nil {
            return
        }

        isLoadingZecPrice = true
        defer { isLoadingZecPrice = false }

        do {
            let price = try await SwapKitPriceService.shared.fetchZecUsdPrice()
            zecPriceUsd = price
        } catch {
            zecPriceUsd = nil
        }
    }

    private var filteredTokens: [SwapKitToken] {
        let query = tokenSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return availableTokens }

        let filtered = availableTokens.filter { token in
            (token.ticker?.lowercased().contains(query) ?? false)
                || (token.name?.lowercased().contains(query) ?? false)
                || token.identifier.lowercased().contains(query)
        }

        return filtered.sorted { lhs, rhs in
            if lhs.chain != rhs.chain {
                return lhs.chain < rhs.chain
            }
            let lt = (lhs.ticker ?? lhs.symbol ?? lhs.identifier).lowercased()
            let rt = (rhs.ticker ?? rhs.symbol ?? rhs.identifier).lowercased()
            return lt < rt
        }
    }

    @MainActor
    private func loadTokensIfNeeded() async {
        if !availableTokens.isEmpty || isLoadingTokens {
            return
        }

        isLoadingTokens = true
        do {
            let tokens = try await SwapKitTokenService.shared.fetchTokens()
            availableTokens = tokens
            isLoadingTokens = false
        } catch {
            isLoadingTokens = false
            if let tokenError = error as? SwapKitTokenService.SwapKitTokenError {
                switch tokenError {
                case .missingApiKey:
                    errorMessage = "SwapKit API key is missing. Set SWAPKIT_KEY in your environment to enable cross-chain swaps."
                default:
                    errorMessage = "Unable to load assets from SwapKit. Please try again."
                }
            } else {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}

struct QRCodeScannerView: UIViewControllerRepresentable {
    let onCodeScanned: (String) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.onCodeScanned = onCodeScanned
        return controller
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {
        // No-op
    }

    final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
        var onCodeScanned: ((String) -> Void)?

        private let session = AVCaptureSession()
        private var previewLayer: AVCaptureVideoPreviewLayer?
        private var permissionDeniedLabel: UILabel?

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black
            
            checkCameraPermission()
        }
        
        private func checkCameraPermission() {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                setupCamera()
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    DispatchQueue.main.async {
                        if granted {
                            self?.setupCamera()
                        } else {
                            self?.showPermissionDenied()
                        }
                    }
                }
            case .denied, .restricted:
                showPermissionDenied()
            @unknown default:
                showPermissionDenied()
            }
        }
        
        private func setupCamera() {
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else {
                return
            }

            session.addInput(input)

            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else { return }
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            output.metadataObjectTypes = [.qr]

            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = view.layer.bounds
            view.layer.addSublayer(previewLayer)
            self.previewLayer = previewLayer
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
            }
        }
        
        private func showPermissionDenied() {
            let label = UILabel()
            label.text = "Camera access is required to scan QR codes.\n\nPlease enable it in Settings."
            label.textColor = .white
            label.textAlignment = .center
            label.numberOfLines = 0
            label.font = .systemFont(ofSize: 16)
            label.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(label)
            
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
                label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
            ])
            
            permissionDeniedLabel = label
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            previewLayer?.frame = view.layer.bounds
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            if !session.isRunning && previewLayer != nil {
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    self?.session.startRunning()
                }
            }
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            if session.isRunning {
                session.stopRunning()
            }
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  object.type == .qr,
                  let value = object.stringValue else { return }

            session.stopRunning()
            onCodeScanned?(value)
        }
    }
}

// MARK: - Token Selector View
private struct TokenSelectorView: View {
    let tokens: [SwapKitToken]
    let isLoading: Bool
    @Binding var searchText: String
    let onSelect: (SwapKitToken) -> Void
    let onDismiss: () -> Void
    
    @AppStorage("handPreference") private var handPreference: String = "right"
    
    private var isRightHanded: Bool { handPreference != "left" }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: ZapSpacing.base) {
                Text("Select Asset")
                    .font(ZapTypography.titleFont)
                    .foregroundColor(ZapColors.primary)
                    .padding(.horizontal, ZapSpacing.xl)
                    .padding(.top, ZapSpacing.xl)
                
                TextField("Search by name, ticker or identifier", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(ZapRadius.medium)
                    .padding(.horizontal, ZapSpacing.xl)
                
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    List(tokens) { token in
                        Button {
                            onSelect(token)
                        } label: {
                            HStack(spacing: ZapSpacing.sm) {
                                VStack(alignment: .leading, spacing: ZapSpacing.xs) {
                                    Text(token.name ?? token.ticker ?? token.symbol ?? token.identifier)
                                        .font(.body)
                                        .foregroundColor(ZapColors.textPrimary)
                                    Text(token.chain)
                                        .font(.footnote)
                                        .foregroundColor(ZapColors.textSecondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            
            // Bottom close button matching CurrencySelectorView pattern
            HStack {
                if isRightHanded {
                    Spacer()
                }
                
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(ZapColors.primary)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                
                if !isRightHanded {
                    Spacer()
                }
            }
            .padding(.horizontal, ZapSpacing.xl)
            .padding(.bottom, ZapSpacing.xl)
        }
        .background(ZapColors.background.ignoresSafeArea())
    }
}
