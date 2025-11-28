import SwiftUI
import Combine
import UIKit
import LocalAuthentication

// MARK: - Offchain Recipient Model

struct OffchainRecipient: Identifiable, Equatable {
    let id: UUID
    var paymentAccount: String  // UPI ID, Alipay ID, WeChat ID, etc.
    var displayName: String     // Optional friendly name
    var amount: String          // Amount in fiat
    var currency: Currency
    var paymentRail: PaymentRail
    var scannedQRData: String?  // Raw QR code data if scanned
    
    init(
        id: UUID = UUID(),
        paymentAccount: String = "",
        displayName: String = "",
        amount: String = "",
        currency: Currency = .inr,
        paymentRail: PaymentRail = .upi,
        scannedQRData: String? = nil
    ) {
        self.id = id
        self.paymentAccount = paymentAccount
        self.displayName = displayName
        self.amount = amount
        self.currency = currency
        self.paymentRail = paymentRail
        self.scannedQRData = scannedQRData
    }
    
    var isValid: Bool {
        !paymentAccount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (Decimal(string: amount.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0) > 0
    }
}

// MARK: - Main View

struct OffchainSendView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var walletViewModel: WalletViewModel
    @EnvironmentObject private var currencyStore: CurrencyStore
    
    // MARK: - Source Address Type
    enum SourceAddressType: String, CaseIterable, Identifiable {
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
    
    // MARK: - State
    @State private var recipients: [OffchainRecipient] = [OffchainRecipient()]
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?
    @State private var activeBatchOrder: BatchOrderDTO?
    @State private var selectedSourceAddressType: SourceAddressType = .unified
    
    // Sheet states
    @State private var isShowingQRScanner: Bool = false
    @State private var editingRecipientIndex: Int?
    @State private var isShowingCurrencySelector: Bool = false
    @State private var isShowingPaymentRailPicker: Bool = false
    @State private var selectedRecipientForEdit: Int = 0
    
    // ZEC price
    @State private var zecPriceUsd: Double?
    @State private var isLoadingZecPrice: Bool = false
    
    // Biometric authentication
    private let biometricService = BiometricAuthService.shared
    private let biometricSettings = BiometricSettingsStore.shared
    
    private let orderService = ZapOrderService()
    
    // MARK: - Source Address
    private var sourceAddress: String {
        guard let info = walletViewModel.walletInfo else { return "—" }
        switch selectedSourceAddressType {
        case .unified:
            return info.address
        case .transparent:
            return info.transparentAddress
        }
    }
    
    // MARK: - Computed Properties
    
    private var totalFiatAmount: Decimal {
        recipients.reduce(Decimal.zero) { sum, recipient in
            let amountStr = recipient.amount.trimmingCharacters(in: .whitespacesAndNewlines)
            return sum + (Decimal(string: amountStr) ?? 0)
        }
    }
    
    private var totalZecEstimate: String? {
        guard let priceUsd = zecPriceUsd, priceUsd > 0 else { return nil }
        
        var totalZec: Decimal = 0
        let priceDecimal = Decimal(priceUsd)
        
        for recipient in recipients {
            let amountStr = recipient.amount.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let fiatAmount = Decimal(string: amountStr), fiatAmount > 0 else { continue }
            
            let rate = currencyStore.convert(amount: 1, from: "USD", to: recipient.currency)
            let zecPriceInCurrency = priceDecimal * rate
            
            guard zecPriceInCurrency > 0 else { continue }
            
            // Apply 1% spread
            let userDisplayRate = zecPriceInCurrency / Decimal(1.01)
            let zecAmount = fiatAmount / userDisplayRate
            totalZec += zecAmount
        }
        
        guard totalZec > 0 else { return nil }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 8
        formatter.minimumFractionDigits = 2
        
        return formatter.string(from: NSDecimalNumber(decimal: totalZec))
    }
    
    private var isFormDisabled: Bool {
        isSubmitting ||
        recipients.isEmpty ||
        !recipients.allSatisfy { $0.isValid } ||
        !walletViewModel.isReadyToSpend
    }
    
    private var hasMultipleCurrencies: Bool {
        let currencies: Set<Currency> = Set(recipients.map { $0.currency })
        return currencies.count > 1
    }
    
    private var hasMultiplePaymentRails: Bool {
        let rails: Set<PaymentRail> = Set(recipients.map { $0.paymentRail })
        return rails.count > 1
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if let batchOrder = activeBatchOrder {
                OffchainBatchTransactionView(
                    batchOrder: batchOrder,
                    onClose: { dismiss() }
                )
            } else {
                mainFormView
            }
        }
        .task {
            await loadZecPriceIfNeeded()
        }
        .sheet(isPresented: $isShowingQRScanner) {
            qrScannerSheet
        }
        .sheet(isPresented: $isShowingCurrencySelector) {
            RecipientCurrencySelectorView(
                selectedCurrency: recipientCurrencyBinding,
                onDismiss: { isShowingCurrencySelector = false }
            )
        }
        .sheet(isPresented: $isShowingPaymentRailPicker) {
            RecipientPaymentRailPickerView(
                selectedRail: recipientPaymentRailBinding,
                onDismiss: { isShowingPaymentRailPicker = false }
            )
        }
    }
    
    // MARK: - Main Form View
    
    private var mainFormView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: ZapSpacing.lg) {
                    headerSection
                    fromSection
                    recipientsSection
                    summarySection
                    
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
                primaryTitle: recipients.count > 1 ? "Send to \(recipients.count) Recipients" : "Send",
                isPrimaryLoading: isSubmitting,
                isPrimaryDisabled: isFormDisabled,
                onBack: { dismiss() },
                onPrimary: { Task { await submitPayments() } }
            )
            .padding(.horizontal, ZapSpacing.xl)
            .padding(.bottom, ZapSpacing.base)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.xs) {
            Text("Send Offchain")
                .font(ZapTypography.titleFont)
                .foregroundColor(ZapColors.primary)
            
            Text("Send to people you know via payment apps.")
                .font(.footnote)
                .foregroundColor(ZapColors.textSecondary)
        }
    }
    
    // MARK: - From Section
    
    private var fromSection: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.sm) {
            Text("From")
                .font(.subheadline)
                .foregroundColor(ZapColors.textSecondary)
            
            Picker("Address Type", selection: $selectedSourceAddressType) {
                ForEach(SourceAddressType.allCases) { type in
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
    }
    
    // MARK: - Recipients Section
    
    private var recipientsSection: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.base) {
            recipientsHeader
            recipientsList
        }
    }
    
    private var recipientsHeader: some View {
        HStack {
            Text("Recipients")
                .font(.subheadline)
                .foregroundColor(ZapColors.textSecondary)
            
            Spacer()
            
            Button(action: addRecipient) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add")
                }
                .font(.subheadline)
                .foregroundColor(ZapColors.primary)
            }
            .buttonStyle(.plain)
        }
    }
    
    private func addRecipient() {
        withAnimation(.easeInOut(duration: 0.2)) {
            let defaultCurrency = currencyStore.selectedCurrency
            let defaultRail = PaymentRail.defaultRail(for: defaultCurrency.rawValue)
            recipients.append(OffchainRecipient(currency: defaultCurrency, paymentRail: defaultRail))
        }
    }
    
    private var recipientsList: some View {
        VStack(spacing: ZapSpacing.sm) {
            ForEach(recipients.indices, id: \.self) { index in
                recipientRow(at: index)
            }
        }
    }
    
    @ViewBuilder
    private func recipientRow(at index: Int) -> some View {
        RecipientCardView(
            recipient: recipientBinding(at: index),
            index: index,
            canDelete: recipients.count > 1,
            onScanQR: { handleScanQR(for: index) },
            onSelectCurrency: { handleSelectCurrency(for: index) },
            onSelectPaymentRail: { handleSelectPaymentRail(for: index) },
            onDelete: { handleDelete(at: index) },
            zecPriceUsd: zecPriceUsd,
            currencyStore: currencyStore
        )
    }
    
    private func recipientBinding(at index: Int) -> Binding<OffchainRecipient> {
        Binding(
            get: { recipients[index] },
            set: { recipients[index] = $0 }
        )
    }
    
    private func handleScanQR(for index: Int) {
        selectedRecipientForEdit = index
        isShowingQRScanner = true
    }
    
    private func handleSelectCurrency(for index: Int) {
        selectedRecipientForEdit = index
        isShowingCurrencySelector = true
    }
    
    private func handleSelectPaymentRail(for index: Int) {
        selectedRecipientForEdit = index
        isShowingPaymentRailPicker = true
    }
    
    private func handleDelete(at index: Int) {
        _ = withAnimation(.easeInOut(duration: 0.2)) {
            recipients.remove(at: index)
        }
    }
    
    // MARK: - Summary Section
    
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.sm) {
            Text("Summary")
                .font(.subheadline)
                .foregroundColor(ZapColors.textSecondary)
            
            VStack(alignment: .leading, spacing: ZapSpacing.xs) {
                HStack {
                    Text("Recipients")
                        .font(.footnote)
                        .foregroundColor(ZapColors.textSecondary)
                    Spacer()
                    Text("\(recipients.count)")
                        .font(.footnote)
                        .foregroundColor(ZapColors.textPrimary)
                }
                
                if hasMultiplePaymentRails {
                    HStack {
                        Text("Payment Methods")
                            .font(.footnote)
                            .foregroundColor(ZapColors.textSecondary)
                        Spacer()
                        Text(uniquePaymentRailsText)
                            .font(.footnote)
                            .foregroundColor(ZapColors.textPrimary)
                    }
                }
                
                if let zecText = totalZecEstimate {
                    HStack {
                        Text("Est. Total ZEC")
                            .font(.footnote)
                            .foregroundColor(ZapColors.textSecondary)
                        Spacer()
                        Text("≈ \(zecText) ZEC")
                            .font(.footnote)
                            .fontWeight(.medium)
                            .foregroundColor(ZapColors.textPrimary)
                    }
                }
                
                Text("Available: \(walletViewModel.spendableZecBalanceText)")
                    .font(.footnote)
                    .foregroundColor(ZapColors.textSecondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(ZapRadius.medium)
            
            if hasMultiplePaymentRails {
                Text("Orders will be grouped by payment method to minimize ZEC transactions.")
                    .font(.caption)
                    .foregroundColor(ZapColors.textSecondary)
            }
        }
    }
    
    private var uniquePaymentRailsText: String {
        let rails: Set<PaymentRail> = Set(recipients.map { $0.paymentRail })
        return rails.map { $0.displayName }.sorted().joined(separator: ", ")
    }
    
    // MARK: - QR Scanner Sheet
    
    private var qrScannerSheet: some View {
        NavigationView {
            OffchainQRScannerSheetView(
                initialCode: recipients[safe: selectedRecipientForEdit]?.paymentAccount ?? "",
                onCodeScanned: { code in
                    handleScannedCode(code, forRecipientAt: selectedRecipientForEdit)
                    isShowingQRScanner = false
                },
                onCancel: {
                    isShowingQRScanner = false
                }
            )
            .navigationTitle("Scan Payment ID")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Bindings
    
    private var recipientCurrencyBinding: Binding<Currency> {
        Binding(
            get: { recipients[safe: selectedRecipientForEdit]?.currency ?? currencyStore.selectedCurrency },
            set: { newValue in
                guard selectedRecipientForEdit < recipients.count else { return }
                recipients[selectedRecipientForEdit].currency = newValue
                // Update payment rail to match currency default
                recipients[selectedRecipientForEdit].paymentRail = PaymentRail.defaultRail(for: newValue.rawValue)
            }
        )
    }
    
    private var recipientPaymentRailBinding: Binding<PaymentRail> {
        Binding(
            get: { recipients[safe: selectedRecipientForEdit]?.paymentRail ?? .upi },
            set: { newValue in
                guard selectedRecipientForEdit < recipients.count else { return }
                recipients[selectedRecipientForEdit].paymentRail = newValue
            }
        )
    }
    
    // MARK: - Actions
    
    private func handleScannedCode(_ code: String, forRecipientAt index: Int) {
        guard index < recipients.count else { return }
        
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try to parse as JSON payload (similar to PayView)
        if let data = trimmed.data(using: .utf8),
           let payload = try? JSONDecoder().decode(OffchainPayCodePayload.self, from: data) {
            recipients[index].paymentAccount = payload.paymentId ?? trimmed
            recipients[index].displayName = payload.displayName ?? ""
            recipients[index].scannedQRData = trimmed
            
            if let amount = payload.amount, !amount.isEmpty {
                recipients[index].amount = amount
            }
            
            if let currencyCode = payload.currency,
               let currency = Currency(rawValue: currencyCode.uppercased()) {
                recipients[index].currency = currency
                recipients[index].paymentRail = PaymentRail.defaultRail(for: currency.rawValue)
            }
            
            if let railString = payload.paymentRail,
               let rail = PaymentRail(rawValue: railString.lowercased()) {
                recipients[index].paymentRail = rail
            }
        } else {
            // Plain text - assume it's just the payment account
            recipients[index].paymentAccount = trimmed
            recipients[index].scannedQRData = trimmed
        }
    }
    
    @MainActor
    private func loadZecPriceIfNeeded() async {
        if isLoadingZecPrice || zecPriceUsd != nil { return }
        
        isLoadingZecPrice = true
        defer { isLoadingZecPrice = false }
        
        do {
            let price = try await SwapKitPriceService.shared.fetchZecUsdPrice()
            zecPriceUsd = price
        } catch {
            zecPriceUsd = nil
        }
    }
    
    @MainActor
    private func submitPayments() async {
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
        
        isSubmitting = true
        
        await walletViewModel.loadWalletIfNeeded()
        
        guard walletViewModel.walletInfo != nil else {
            isSubmitting = false
            errorMessage = "Wallet is not ready. Please wait for sync to complete."
            return
        }
        
        // Validate all recipients
        for (index, recipient) in recipients.enumerated() {
            if !recipient.isValid {
                isSubmitting = false
                errorMessage = "Recipient \(index + 1) is missing required information."
                return
            }
        }
        
        do {
            // Convert recipients to order items
            let orderItems: [BatchOrderItem] = recipients.map { recipient in
                let amountStr = recipient.amount.trimmingCharacters(in: .whitespacesAndNewlines)
                let fiatAmount = Decimal(string: amountStr) ?? 0
                
                return BatchOrderItem(
                    merchantCode: recipient.paymentAccount.trimmingCharacters(in: .whitespacesAndNewlines),
                    merchantName: recipient.displayName.isEmpty ? nil : recipient.displayName,
                    fiatAmount: fiatAmount,
                    fiatCurrency: recipient.currency.rawValue,
                    paymentRail: recipient.paymentRail.rawValue,
                    scannedQRCodeData: recipient.scannedQRData
                )
            }
            
            // Create batch order using selected source address
            let batchOrder = try await orderService.createBatchOrder(
                userWalletAddress: sourceAddress,
                items: orderItems
            )
            
            activeBatchOrder = batchOrder
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

// MARK: - Recipient Card View

private struct RecipientCardView: View {
    @Binding var recipient: OffchainRecipient
    let index: Int
    let canDelete: Bool
    let onScanQR: () -> Void
    let onSelectCurrency: () -> Void
    let onSelectPaymentRail: () -> Void
    let onDelete: () -> Void
    let zecPriceUsd: Double?
    let currencyStore: CurrencyStore
    
    private var zecEstimate: String? {
        guard let priceUsd = zecPriceUsd, priceUsd > 0 else { return nil }
        
        let amountStr = recipient.amount.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let fiatAmount = Decimal(string: amountStr), fiatAmount > 0 else { return nil }
        
        let priceDecimal = Decimal(priceUsd)
        let rate = currencyStore.convert(amount: 1, from: "USD", to: recipient.currency)
        let zecPriceInCurrency = priceDecimal * rate
        
        guard zecPriceInCurrency > 0 else { return nil }
        
        // Apply 1% spread
        let userDisplayRate = zecPriceInCurrency / Decimal(1.01)
        let zecAmount = fiatAmount / userDisplayRate
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 8
        formatter.minimumFractionDigits = 2
        
        return formatter.string(from: NSDecimalNumber(decimal: zecAmount))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.sm) {
            // Header with recipient number and delete button
            HStack {
                Text("Recipient \(index + 1)")
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundColor(ZapColors.textPrimary)
                
                Spacer()
                
                if canDelete {
                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ZapColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Payment Account Input
            VStack(alignment: .leading, spacing: ZapSpacing.xs) {
                Text("Payment ID")
                    .font(.caption)
                    .foregroundColor(ZapColors.textSecondary)
                
                HStack(spacing: 8) {
                    TextField("UPI ID, Alipay ID, etc.", text: $recipient.paymentAccount)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                    
                    Button(action: onScanQR) {
                        Image(systemName: "qrcode.viewfinder")
                            .foregroundColor(ZapColors.primary)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(ZapRadius.medium)
            }
            
            // Display Name (optional)
            VStack(alignment: .leading, spacing: ZapSpacing.xs) {
                Text("Name (optional)")
                    .font(.caption)
                    .foregroundColor(ZapColors.textSecondary)
                
                TextField("e.g., John Doe", text: $recipient.displayName)
                    .textInputAutocapitalization(.words)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(ZapRadius.medium)
            }
            
            // Amount and Currency
            HStack(spacing: ZapSpacing.sm) {
                VStack(alignment: .leading, spacing: ZapSpacing.xs) {
                    Text("Amount")
                        .font(.caption)
                        .foregroundColor(ZapColors.textSecondary)
                    
                    HStack(spacing: 0) {
                        Button(action: onSelectCurrency) {
                            HStack(spacing: 4) {
                                Text(recipient.currency.symbol)
                                    .font(.headline)
                                    .foregroundColor(ZapColors.textPrimary)
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                                    .foregroundColor(ZapColors.textSecondary)
                            }
                            .padding(.leading, ZapSpacing.sm)
                            .padding(.trailing, ZapSpacing.xs)
                        }
                        .buttonStyle(.plain)
                        
                        TextField("0.00", text: $recipient.amount)
                            .keyboardType(.decimalPad)
                            .padding(.vertical, 12)
                            .padding(.trailing, ZapSpacing.sm)
                    }
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(ZapRadius.medium)
                }
                
                VStack(alignment: .leading, spacing: ZapSpacing.xs) {
                    Text("Method")
                        .font(.caption)
                        .foregroundColor(ZapColors.textSecondary)
                    
                    Button(action: onSelectPaymentRail) {
                        HStack {
                            Text(recipient.paymentRail.displayName)
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
                }
            }
            
            // ZEC Estimate
            if let zecText = zecEstimate {
                Text("≈ \(zecText) ZEC")
                    .font(.caption)
                    .foregroundColor(ZapColors.textSecondary)
            }
        }
        .padding(ZapSpacing.base)
        .background(Color(.secondarySystemBackground).opacity(0.5))
        .cornerRadius(ZapRadius.medium)
    }
}

// MARK: - Supporting Views

private struct RecipientCurrencySelectorView: View {
    @Binding var selectedCurrency: Currency
    let onDismiss: () -> Void
    @AppStorage("handPreference") private var handPreference: String = "right"
    
    private var isRightHanded: Bool { handPreference != "left" }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: ZapSpacing.base) {
                Text("Select Currency")
                    .font(ZapTypography.titleFont)
                    .foregroundColor(ZapColors.primary)
                    .padding(.horizontal, ZapSpacing.xl)
                    .padding(.top, ZapSpacing.xl)
                
                List(Currency.allCases) { currency in
                    Button {
                        selectedCurrency = currency
                        onDismiss()
                    } label: {
                        HStack {
                            Text(currency.symbol)
                                .font(.headline)
                                .frame(width: 32)
                            
                            VStack(alignment: .leading) {
                                Text(currency.rawValue)
                                    .font(.body)
                                    .foregroundColor(ZapColors.textPrimary)
                                Text(currency.name)
                                    .font(.caption)
                                    .foregroundColor(ZapColors.textSecondary)
                            }
                            
                            Spacer()
                            
                            if selectedCurrency == currency {
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
            
            HStack {
                if isRightHanded { Spacer() }
                
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
                
                if !isRightHanded { Spacer() }
            }
            .padding(.horizontal, ZapSpacing.xl)
            .padding(.bottom, ZapSpacing.xl)
        }
        .background(ZapColors.background.ignoresSafeArea())
    }
}

private struct RecipientPaymentRailPickerView: View {
    @Binding var selectedRail: PaymentRail
    let onDismiss: () -> Void
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
                        onDismiss()
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
            
            HStack {
                if isRightHanded { Spacer() }
                
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
                
                if !isRightHanded { Spacer() }
            }
            .padding(.horizontal, ZapSpacing.xl)
            .padding(.bottom, ZapSpacing.xl)
        }
        .background(ZapColors.background.ignoresSafeArea())
    }
}

// MARK: - QR Scanner Sheet

private struct OffchainQRScannerSheetView: View {
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
                    Text("Scan payment QR code")
                        .font(.subheadline)
                        .foregroundColor(ZapColors.textSecondary)
                    
                    QRCodeScannerView(
                        onCodeScanned: { code in
                            let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
                            manualCode = trimmed
                            onCodeScanned(trimmed)
                        },
                        onCancel: onCancel
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
                            TextField("Payment ID", text: $manualCode)
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
                primaryTitle: "Use This ID",
                isPrimaryLoading: false,
                isPrimaryDisabled: isPrimaryDisabled,
                onBack: onCancel,
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

// MARK: - Payload Model

private struct OffchainPayCodePayload: Decodable {
    let paymentId: String?
    let displayName: String?
    let amount: String?
    let currency: String?
    let paymentRail: String?
}

// MARK: - Array Extension

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0 && index < count else { return nil }
        return self[index]
    }
}
