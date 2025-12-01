import SwiftUI
import Combine
import UIKit
import LocalAuthentication

struct PayView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var walletViewModel: WalletViewModel
    @EnvironmentObject private var currencyStore: CurrencyStore

    @State private var merchantName: String = ""
    @State private var merchantCode: String = ""
    @State private var scannedQRCodeData: String = ""
    @State private var fiatAmount: String = ""
    @State private var derivedAmountFromCode: Bool = false
    @State private var isShowingQRScanner: Bool = false
    @State private var isShowingCurrencySelector: Bool = false
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?
    @State private var activeOrder: ZapOrderDTO?

    @State private var zecPriceUsd: Double?
    @State private var isLoadingZecPrice: Bool = false
    @State private var zecEstimateText: String?
    @State private var selectedPaymentRail: PaymentRail = .upi
    @State private var isShowingPaymentRailPicker: Bool = false
    
    // Biometric authentication
    private let biometricService = BiometricAuthService.shared
    private let biometricSettings = BiometricSettingsStore.shared

    private let orderService = ZapOrderService()

    private var normalizedAmount: String {
        fiatAmount.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isFormDisabled: Bool {
        isSubmitting
            || merchantCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || normalizedAmount.isEmpty
            || !walletViewModel.isReadyToSpend
    }

    var body: some View {
        NavigationView {
            Group {
                if let order = activeOrder {
                    ZapPayTransactionView(
                        initialOrder: order,
                        onClose: {
                            dismiss()
                        }
                    )
                } else {
                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: ZapSpacing.lg) {
                                merchantSection
                                amountSection
                                paymentRailSection
                                detailsSection

                                if let error = errorMessage {
                                    Text(error)
                                        .font(.footnote)
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(.vertical, ZapSpacing.lg)
                            .padding(.horizontal, ZapSpacing.lg)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(ZapRadius.medium)
                            .padding(.horizontal, ZapSpacing.xl)
                            .padding(.top, ZapSpacing.base)
                            .padding(.bottom, ZapSpacing.lg)
                        }

                        ZapBottomBar(
                            primaryTitle: "Pay",
                            isPrimaryLoading: isSubmitting,
                            isPrimaryDisabled: isFormDisabled,
                            onBack: {
                                dismiss()
                            },
                            onPrimary: {
                                Task { await submitPayment() }
                            }
                        )
                        .padding(.horizontal, ZapSpacing.xl)
                        .padding(.bottom, ZapSpacing.base)
                    }
                }
            }
            .background(ZapColors.background.ignoresSafeArea())
            .navigationTitle("Pay")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadZecPriceIfNeeded()
            }
            .onChange(of: fiatAmount) { oldValue, newValue in
                updateZecEstimate()
            }
            .onAppear {
                if merchantCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    isShowingQRScanner = true
                }
                selectedPaymentRail = PaymentRail.defaultRail(for: currencyStore.selectedCurrency.rawValue)
            }
            .sheet(isPresented: $isShowingCurrencySelector) {
                CurrencySelectorView()
            }
            .sheet(isPresented: $isShowingPaymentRailPicker) {
                PaymentRailPickerView(selectedRail: $selectedPaymentRail)
            }
            .onChange(of: currencyStore.selectedCurrency) { oldValue, newValue in
                selectedPaymentRail = PaymentRail.defaultRail(for: newValue.rawValue)
            }
            .sheet(isPresented: $isShowingQRScanner) {
                NavigationView {
                    PayQRScannerSheetView(
                        initialCode: merchantCode,
                        onCodeScanned: { code in
                            handleScannedCode(code)
                            isShowingQRScanner = false
                        },
                        onCancel: {
                            isShowingQRScanner = false
                        }
                    )
                    .navigationTitle("Scan facilitator ID")
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
    }

    private var merchantSection: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.sm) {
            Text("Facilitator")
                .font(.subheadline)
                .foregroundColor(ZapColors.textSecondary)

            HStack(spacing: 8) {
                TextField("Facilitator ID or code", text: $merchantCode)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .multilineTextAlignment(.leading)

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

            if !merchantName.isEmpty {
                Text(merchantName)
                    .font(.headline)
                    .foregroundColor(ZapColors.textPrimary)
            }

            if merchantCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Paste or scan the facilitator's payment code to start.")
                    .font(.footnote)
                    .foregroundColor(ZapColors.textSecondary)
            }
        }
    }

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.sm) {
            Text("Amount")
                .font(.subheadline)
                .foregroundColor(ZapColors.textSecondary)

            HStack(spacing: 0) {
                Button {
                    isShowingCurrencySelector = true
                } label: {
                    HStack(spacing: 4) {
                        Text(currencyStore.selectedCurrency.symbol)
                            .font(.headline)
                            .foregroundColor(ZapColors.textPrimary)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(ZapColors.textSecondary)
                    }
                    .padding(.leading, ZapSpacing.base)
                    .padding(.trailing, ZapSpacing.xs)
                }
                .buttonStyle(.plain)

                TextField("Amount", text: $fiatAmount)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.leading)
                    .padding(.vertical, 12)
                    .padding(.trailing, ZapSpacing.base)
            }
            .background(Color(.secondarySystemBackground))
            .cornerRadius(ZapRadius.medium)

            if let zecText = zecEstimateText {
                Text("≈ \(zecText) ZEC at current rate")
                    .font(.footnote)
                    .foregroundColor(ZapColors.textSecondary)
            }

            if derivedAmountFromCode {
                Text("Amount suggested by payment code; you can adjust if needed.")
                    .font(.footnote)
                    .foregroundColor(ZapColors.textSecondary)
            } else {
                Text("Enter the amount you want to pay.")
                    .font(.footnote)
                    .foregroundColor(ZapColors.textSecondary)
            }
        }
    }

    private var paymentRailSection: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.sm) {
            Text("Payment Method")
                .font(.subheadline)
                .foregroundColor(ZapColors.textSecondary)

            Button {
                isShowingPaymentRailPicker = true
            } label: {
                HStack {
                    Text(selectedPaymentRail.displayName)
                        .font(.body)
                        .foregroundColor(ZapColors.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(ZapColors.textSecondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(ZapRadius.medium)
            }
            .buttonStyle(.plain)

            Text("Select how the facilitator will receive fiat payment.")
                .font(.footnote)
                .foregroundColor(ZapColors.textSecondary)
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.sm) {
            Text("Details")
                .font(.subheadline)
                .foregroundColor(ZapColors.textSecondary)

            Text("This will create a crypto payment to the matched facilitator once the payment code is verified.")
                .font(.footnote)
                .foregroundColor(ZapColors.textSecondary)
        }
    }

    private func handleScannedCode(_ code: String) {
        errorMessage = nil
        derivedAmountFromCode = false
        
        // Always store the raw QR code data for the facilitator to scan later
        scannedQRCodeData = code

        if let data = code.data(using: .utf8),
           let payload = try? JSONDecoder().decode(PayCodePayload.self, from: data) {
            merchantCode = payload.merchantId ?? code
            merchantName = payload.merchantName ?? ""
            if let amount = payload.fiatAmount, !amount.isEmpty {
                fiatAmount = amount
                derivedAmountFromCode = true
                updateZecEstimate()
            }
        } else {
            merchantCode = code
            merchantName = ""
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
            updateZecEstimate()
        } catch {
            zecPriceUsd = nil
        }
    }

    private func updateZecEstimate() {
        guard
            let priceUsd = zecPriceUsd,
            !normalizedAmount.isEmpty,
            let fiatDecimal = Decimal(string: normalizedAmount),
            fiatDecimal > 0
        else {
            zecEstimateText = nil
            return
        }

        let priceDecimal = Decimal(priceUsd)
        guard priceDecimal > 0 else {
            zecEstimateText = nil
            return
        }
        
        // Convert ZEC/USD to ZEC/Selected
        // Rate = USD/Selected
        // ZEC/Selected = ZEC/USD * USD/Selected
        // ZEC Amount = FiatAmount / (ZEC/Selected)
        
        let rate = currencyStore.convert(amount: 1, from: "USD", to: currencyStore.selectedCurrency)
        let zecPriceInSelected = priceDecimal * rate
        
        guard zecPriceInSelected > 0 else {
            zecEstimateText = nil
            return
        }

        // Apply 1% spread: user pays more ZEC (effective rate is divided by 1.01)
        let userDisplayRate = zecPriceInSelected / Decimal(1.01)
        let zecDecimal = fiatDecimal / userDisplayRate

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 8
        formatter.minimumFractionDigits = 2

        let number = NSDecimalNumber(decimal: zecDecimal)
        zecEstimateText = formatter.string(from: number)
    }

    @MainActor
    private func submitPayment() async {
        errorMessage = nil
        
        // Check if biometric authentication is required
        if biometricSettings.shouldRequireBiometric() {
            do {
                let authenticated = try await biometricService.authenticateForTransaction()
                guard authenticated else {
                    errorMessage = "Authentication required to pay."
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
        
        isSubmitting = true

        let trimmedCode = merchantCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let amountString = normalizedAmount

        guard !trimmedCode.isEmpty else {
            isSubmitting = false
            errorMessage = "Facilitator code is required."
            return
        }

        guard let amountDecimal = Decimal(string: amountString), amountDecimal > 0 else {
            isSubmitting = false
            errorMessage = "Please enter a valid amount greater than zero."
            return
        }

        do {
            await walletViewModel.loadWalletIfNeeded()

            guard let walletInfo = walletViewModel.walletInfo else {
                isSubmitting = false
                errorMessage = "Wallet is not ready. Please wait for sync to complete."
                return
            }

            let trimmedName = merchantName.trimmingCharacters(in: .whitespacesAndNewlines)

            let trimmedQRCode = scannedQRCodeData.trimmingCharacters(in: .whitespacesAndNewlines)
            
            let order = try await orderService.createOrder(
                userWalletAddress: walletInfo.address,
                merchantCode: trimmedCode,
                merchantName: trimmedName.isEmpty ? nil : trimmedName,
                fiatAmount: amountDecimal,
                fiatCurrency: currencyStore.selectedCurrency.rawValue,
                paymentRail: selectedPaymentRail.rawValue,
                scannedQRCodeData: trimmedQRCode.isEmpty ? nil : trimmedQRCode
            )

            activeOrder = order
            isSubmitting = false
        } catch {
            isSubmitting = false
            if let localized = error as? LocalizedError, let description = localized.errorDescription {
                errorMessage = description
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct PayCodePayload: Decodable {
    let merchantId: String?
    let merchantName: String?
    let fiatAmount: String?
}

enum PaymentRail: String, CaseIterable, Identifiable {
    case upi = "upi"
    case alipay = "alipay"
    case wechatPay = "wechat_pay"
    case pix = "pix"
    case promptpay = "promptpay"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .upi: return "UPI"
        case .alipay: return "Alipay"
        case .wechatPay: return "WeChat Pay"
        case .pix: return "PIX"
        case .promptpay: return "PromptPay"
        }
    }

    static func defaultRail(for currencyCode: String) -> PaymentRail {
        switch currencyCode.uppercased() {
        case "INR":
            return .upi
        case "CNY":
            return .alipay
        case "THB":
            return .promptpay
        case "BRL":
            return .pix
        default:
            return .upi
        }
    }
}

private struct PaymentRailPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedRail: PaymentRail
    @AppStorage("handPreference") private var handPreference: String = "right"
    
    private var isRightHanded: Bool { handPreference != "left" }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: ZapSpacing.base) {
                Text("Payment Method")
                    .font(ZapTypography.titleFont)
                    .foregroundColor(ZapColors.primary)
                    .padding(.horizontal, ZapSpacing.xl)
                    .padding(.top, ZapSpacing.xl)
                
                List(PaymentRail.allCases) { rail in
                    Button {
                        selectedRail = rail
                        dismiss()
                    } label: {
                        HStack {
                            Text(rail.displayName)
                                .font(.body)
                                .foregroundColor(ZapColors.textPrimary)
                            Spacer()
                            if rail == selectedRail {
                                Image(systemName: "checkmark")
                                    .foregroundColor(ZapColors.primary)
                            }
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
            
            // Bottom close button matching CurrencySelectorView pattern
            HStack {
                if isRightHanded {
                    Spacer()
                }
                
                Button {
                    dismiss()
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

private struct PayQRScannerSheetView: View {
    let initialCode: String
    let onCodeScanned: (String) -> Void
    let onCancel: () -> Void

    @State private var manualCode: String

    init(
        initialCode: String,
        onCodeScanned: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.initialCode = initialCode
        self.onCodeScanned = onCodeScanned
        self.onCancel = onCancel
        _manualCode = State(initialValue: initialCode)
    }
    
    private var isPrimaryDisabled: Bool {
        manualCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: ZapSpacing.lg) {
                    Text("Scan facilitator QR")
                        .font(.subheadline)
                        .foregroundColor(ZapColors.textSecondary)

                    QRCodeScannerView(
                        onCodeScanned: { code in
                            let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
                            manualCode = trimmed
                            onCodeScanned(trimmed)
                        },
                        onCancel: {
                            onCancel()
                        }
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: ZapRadius.medium))

                    VStack(alignment: .leading, spacing: ZapSpacing.sm) {
                        Text("Or enter manually")
                            .font(.subheadline)
                            .foregroundColor(ZapColors.textSecondary)

                        HStack(spacing: 0) {
                            TextField("Facilitator ID", text: $manualCode)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .padding()

                            Button("Paste") {
                                if let value = UIPasteboard.general.string, !value.isEmpty {
                                    manualCode = value.trimmingCharacters(in: .whitespacesAndNewlines)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .font(.subheadline)
                            .foregroundColor(ZapColors.primary)
                        }
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(ZapRadius.medium)
                    }
                }
                .padding(.horizontal, ZapSpacing.xl)
                .padding(.top, ZapSpacing.base)
                .padding(.bottom, ZapSpacing.lg)
            }

            ZapBottomBar(
                primaryTitle: "Proceed to Amount",
                isPrimaryLoading: false,
                isPrimaryDisabled: isPrimaryDisabled,
                onBack: {
                    onCancel()
                },
                onPrimary: {
                    let trimmed = manualCode.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onCodeScanned(trimmed)
                }
            )
            .padding(.horizontal, ZapSpacing.xl)
            .padding(.bottom, ZapSpacing.base)
        }
        .background(ZapColors.background.ignoresSafeArea())
    }
}

private struct ZapPayTransactionView: View {
    @EnvironmentObject private var walletViewModel: WalletViewModel

    let initialOrder: ZapOrderDTO
    let onClose: () -> Void

    @State private var currentOrder: ZapOrderDTO
    @State private var isPolling: Bool = true
    @State private var isSendingZec: Bool = false
    @State private var didSendZec: Bool = false
    @State private var isShowingCancelAlert: Bool = false
    @State private var isCancellingOrder: Bool = false
    @State private var errorMessage: String?

    private let orderService = ZapOrderService()

    init(initialOrder: ZapOrderDTO, onClose: @escaping () -> Void) {
        self.initialOrder = initialOrder
        self.onClose = onClose
        _currentOrder = State(initialValue: initialOrder)
    }

    private var merchantTitle: String {
        currentOrder.merchantName ?? currentOrder.merchantCode
    }

    private var statusText: String {
        currentOrder.status.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private var fiatText: String {
        String(format: "%.2f %@", currentOrder.fiatAmount, currentOrder.fiatCurrency)
    }

    private var zecText: String {
        String(format: "%.8f ZEC", currentOrder.zecAmount)
    }

    private var merchantWalletAddress: String? {
        guard let raw = currentOrder.merchantZecAddress?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        return raw
    }

    private var createdAtText: String? {
        guard let createdAt = currentOrder.createdAt,
              let date = ISO8601DateFormatter().date(from: createdAt) else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private var canSendZec: Bool {
        isFiatPaid
            && merchantWalletAddress != nil
            && currentOrder.zecAmount > 0
            && walletViewModel.isReadyToSpend
            && !isSendingZec
            && !didSendZec
    }

    private var isFiatPaid: Bool {
        currentOrder.status == "fiat_sent"
    }

    private var isCompleted: Bool {
        currentOrder.status == "completed" || currentOrder.status == "zec_sent"
    }

    private var isFailedOrCancelled: Bool {
        currentOrder.status == "failed" || currentOrder.status == "cancelled"
    }

    private var canCancelOrder: Bool {
        currentOrder.status == "pending" && !isFailedOrCancelled && !isCompleted && !didSendZec
    }

    private var primaryTitle: String {
        if didSendZec || isCompleted || isFailedOrCancelled {
            return "Close"
        } else if isSendingZec {
            return "Sending..."
        } else if canSendZec {
            return "Send ZEC"
        } else {
            return "Matching..."
        }
    }

    private var isPrimaryDisabled: Bool {
        if didSendZec || isCompleted || isFailedOrCancelled {
            return false
        }
        return !canSendZec || isSendingZec
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: ZapSpacing.lg) {
                    VStack(alignment: .leading, spacing: ZapSpacing.xs) {
                        Text("Confirm Pay")
                            .font(ZapTypography.titleFont)
                            .foregroundColor(ZapColors.primary)

                        Text("Stay on this screen while we match your payment.")
                            .font(.footnote)
                            .foregroundColor(ZapColors.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: ZapSpacing.sm) {
                        Text("Amount to Pay")
                            .font(.subheadline)
                            .foregroundColor(ZapColors.textSecondary)

                        Text(fiatText)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(ZapColors.textPrimary)

                        Text(zecText)
                            .font(.footnote)
                            .foregroundColor(ZapColors.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: ZapSpacing.sm) {
                        Text("Facilitator")
                            .font(.subheadline)
                            .foregroundColor(ZapColors.textSecondary)

                        Text(merchantTitle)
                            .font(.body)
                            .foregroundColor(ZapColors.textPrimary)

                        if let address = merchantWalletAddress {
                            Text(address)
                                .font(.footnote)
                                .foregroundColor(ZapColors.textSecondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }

                    VStack(alignment: .leading, spacing: ZapSpacing.sm) {
                        Text("Status")
                            .font(.subheadline)
                            .foregroundColor(ZapColors.textSecondary)

                        HStack(spacing: ZapSpacing.sm) {
                            Text(statusText)
                                .font(.footnote)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(ZapColors.background)
                                .foregroundColor(ZapColors.textPrimary)
                                .clipShape(Capsule())

                            if !isCompleted && !isFailedOrCancelled && !didSendZec && !canSendZec {
                                ProgressView()
                            }
                        }

                        if isFailedOrCancelled {
                            Text("This order was cancelled or failed. You can close this screen.")
                                .font(.footnote)
                                .foregroundColor(ZapColors.textSecondary)
                        } else if isCompleted || didSendZec {
                            Text("ZEC sent. You can close this screen and view the order under Transactions.")
                                .font(.footnote)
                                .foregroundColor(ZapColors.textSecondary)
                        } else if isFiatPaid && merchantWalletAddress != nil {
                            Text("Fiat payment confirmed. Send ZEC to the facilitator's wallet above to finish.")
                                .font(.footnote)
                                .foregroundColor(ZapColors.textSecondary)
                        } else if merchantWalletAddress == nil {
                            Text("Finding the best match for your payment…")
                                .font(.footnote)
                                .foregroundColor(ZapColors.textSecondary)
                        } else {
                            Text("Match found. Waiting for fiat confirmation from the facilitator…")
                                .font(.footnote)
                                .foregroundColor(ZapColors.textSecondary)
                        }

                        if let created = createdAtText {
                            Text(created)
                                .font(.caption)
                                .foregroundColor(ZapColors.textSecondary)
                        }
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                }
                .padding(.vertical, ZapSpacing.lg)
                .padding(.horizontal, ZapSpacing.lg)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(ZapRadius.medium)
                .padding(.horizontal, ZapSpacing.xl)
                .padding(.top, ZapSpacing.base)
                .padding(.bottom, ZapSpacing.lg)
            }

            ZapBottomBar(
                primaryTitle: primaryTitle,
                isPrimaryLoading: isSendingZec,
                isPrimaryDisabled: isPrimaryDisabled,
                onBack: {
                    handleBackTap()
                },
                onPrimary: {
                    handlePrimaryTap()
                }
            )
            .padding(.horizontal, ZapSpacing.xl)
            .padding(.bottom, ZapSpacing.base)
        }
        .task {
            await startPolling()
        }
        .onDisappear {
            isPolling = false
        }
        .alert("Cancel payment?", isPresented: $isShowingCancelAlert) {
            Button("Keep matching", role: .cancel) { }
            Button("Cancel payment", role: .destructive) {
                Task { await cancelOrder() }
            }
        } message: {
            Text("This will cancel your payment and return you to Home.")
        }
    }

    private func handleBackTap() {
        if canCancelOrder {
            isShowingCancelAlert = true
        } else {
            onClose()
        }
    }

    private func handlePrimaryTap() {
        if didSendZec || isCompleted || isFailedOrCancelled {
            onClose()
        } else if canSendZec {
            Task { await sendZec() }
        }
    }

    @MainActor
    private func startPolling() async {
        await walletViewModel.loadWalletIfNeeded()

        guard let walletInfo = walletViewModel.walletInfo else {
            errorMessage = "Wallet is not ready. Please wait for sync to complete."
            return
        }

        let walletAddress = walletInfo.address

        while isPolling && !didSendZec && !isCompleted && !isFailedOrCancelled && !Task.isCancelled {
            do {
                let orders = try await orderService.listOrdersForUser(
                    userWalletAddress: walletAddress,
                    status: nil
                )

                if let updated = orders.first(where: { $0.orderId == currentOrder.orderId }) {
                    currentOrder = updated
                    errorMessage = nil
                }
            } catch {
                if let localized = error as? LocalizedError, let description = localized.errorDescription {
                    errorMessage = description
                } else {
                    errorMessage = error.localizedDescription
                }
            }

            try? await Task.sleep(nanoseconds: 5_000_000_000)
        }
    }

    @MainActor
    private func cancelOrder() async {
        if isCancellingOrder {
            return
        }

        isCancellingOrder = true
        defer { isCancellingOrder = false }

        errorMessage = nil

        await walletViewModel.loadWalletIfNeeded()

        guard let walletInfo = walletViewModel.walletInfo else {
            errorMessage = "Wallet is not ready. Please wait for sync to complete."
            return
        }

        do {
            _ = try await orderService.cancelOrder(
                orderId: currentOrder.orderId,
                userWalletAddress: walletInfo.address,
                reason: "User cancelled from matching screen"
            )
            isPolling = false
            onClose()
        } catch {
            if let localized = error as? LocalizedError, let description = localized.errorDescription {
                errorMessage = description
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    @MainActor
    private func sendZec() async {
        guard let merchantAddress = merchantWalletAddress else { return }

        errorMessage = nil
        isSendingZec = true

        // Check if we have spread amounts
        let hasPlatformSpread = currentOrder.platformZecAmount != nil &&
                                currentOrder.platformZecAmount! > 0 &&
                                !(currentOrder.platformZecAddress?.isEmpty ?? true)

        do {
            // Send to facilitator
            if let merchantZecAmount = currentOrder.merchantZecAmount, merchantZecAmount > 0 {
                let merchantAmountString = try formatZecAmount(merchantZecAmount)
                _ = try await walletViewModel.send(
                    to: merchantAddress,
                    amount: merchantAmountString,
                    memo: "Zapp order \(currentOrder.orderId) - facilitator"
                )
            } else {
                // Fallback to full amount if no spread data
                let fullAmountString = try formatZecAmount(currentOrder.zecAmount)
                _ = try await walletViewModel.send(
                    to: merchantAddress,
                    amount: fullAmountString,
                    memo: "Zapp order \(currentOrder.orderId)"
                )
            }

            // Send platform spread if configured
            if hasPlatformSpread,
               let platformAddress = currentOrder.platformZecAddress,
               let platformAmount = currentOrder.platformZecAmount {
                let platformAmountString = try formatZecAmount(platformAmount)
                _ = try await walletViewModel.send(
                    to: platformAddress,
                    amount: platformAmountString,
                    memo: "Zapp platform fee - \(currentOrder.orderId)"
                )
            }

            isSendingZec = false
            didSendZec = true
        } catch {
            isSendingZec = false
            if let walletError = error as? WalletError, case .invalidRecipient = walletError {
                errorMessage = "Destination is not a valid Zcash address for this wallet. Please contact support."
            } else {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func formatZecAmount(_ amount: Double) throws -> String {
        let zecDecimal = Decimal(amount)
        let number = NSDecimalNumber(decimal: zecDecimal)

        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 8
        formatter.minimumFractionDigits = 1
        formatter.minimumIntegerDigits = 1

        guard let amountString = formatter.string(from: number) else {
            throw WalletError.invalidAmount
        }

        return amountString
    }
}
