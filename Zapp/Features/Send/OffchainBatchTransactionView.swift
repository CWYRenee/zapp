import SwiftUI

// MARK: - Batch Transaction View

struct OffchainBatchTransactionView: View {
    @EnvironmentObject private var walletViewModel: WalletViewModel
    
    let batchOrder: BatchOrderDTO
    let onClose: () -> Void
    
    @State private var currentBatch: BatchOrderDTO
    @State private var isPolling: Bool = true
    @State private var isSendingZec: Bool = false
    @State private var sentGroupIds: Set<String> = []
    @State private var errorMessage: String?
    
    private let orderService = ZapOrderService()
    
    init(batchOrder: BatchOrderDTO, onClose: @escaping () -> Void) {
        self.batchOrder = batchOrder
        self.onClose = onClose
        _currentBatch = State(initialValue: batchOrder)
    }
    
    // MARK: - Computed Properties
    
    private var totalFiatText: String {
        // Group by currency and sum
        var currencyTotals: [String: Double] = [:]
        for order in currentBatch.orders {
            currencyTotals[order.fiatCurrency, default: 0] += order.fiatAmount
        }
        
        return currencyTotals.map { currency, amount in
            String(format: "%.2f %@", amount, currency)
        }.joined(separator: " + ")
    }
    
    private var totalZecText: String {
        String(format: "%.8f ZEC", currentBatch.totalZecAmount)
    }
    
    private var statusText: String {
        currentBatch.status.replacingOccurrences(of: "_", with: " ").capitalized
    }
    
    private var isCompleted: Bool {
        currentBatch.status == "completed"
    }
    
    private var isFailedOrCancelled: Bool {
        currentBatch.status == "failed" || currentBatch.status == "cancelled"
    }
    
    private var allGroupsSent: Bool {
        currentBatch.merchantGroups.allSatisfy { group in
            sentGroupIds.contains(group.groupId) || group.status == "completed"
        }
    }
    
    private var readyToSendGroups: [MerchantGroupDTO] {
        currentBatch.merchantGroups.filter { group in
            group.status == "fiat_sent" &&
            group.merchantZecAddress != nil &&
            !sentGroupIds.contains(group.groupId)
        }
    }
    
    private var pendingGroups: [MerchantGroupDTO] {
        currentBatch.merchantGroups.filter { group in
            group.status == "pending" || group.status == "accepted"
        }
    }
    
    private var primaryTitle: String {
        if allGroupsSent || isCompleted || isFailedOrCancelled {
            return "Close"
        } else if isSendingZec {
            return "Sending..."
        } else if !readyToSendGroups.isEmpty {
            return "Send ZEC (\(readyToSendGroups.count))"
        } else {
            return "Matching..."
        }
    }
    
    private var isPrimaryDisabled: Bool {
        if allGroupsSent || isCompleted || isFailedOrCancelled {
            return false
        }
        return readyToSendGroups.isEmpty || isSendingZec
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: ZapSpacing.lg) {
                    headerSection
                    summarySection
                    merchantGroupsSection
                    ordersSection
                    
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
                onBack: { onClose() },
                onPrimary: { handlePrimaryTap() }
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
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.xs) {
            Text("Confirm Batch Payment")
                .font(ZapTypography.titleFont)
                .foregroundColor(ZapColors.primary)
            
            Text("Stay on this screen while we match your payments to facilitators.")
                .font(.footnote)
                .foregroundColor(ZapColors.textSecondary)
        }
    }
    
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.sm) {
            Text("Total Amount")
                .font(.subheadline)
                .foregroundColor(ZapColors.textSecondary)
            
            Text(totalFiatText)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(ZapColors.textPrimary)
            
            Text(totalZecText)
                .font(.footnote)
                .foregroundColor(ZapColors.textSecondary)
            
            HStack(spacing: ZapSpacing.sm) {
                Text(statusText)
                    .font(.footnote)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ZapColors.background)
                    .foregroundColor(ZapColors.textPrimary)
                    .clipShape(Capsule())
                
                if !isCompleted && !isFailedOrCancelled && !allGroupsSent {
                    ProgressView()
                }
            }
        }
    }
    
    private var merchantGroupsSection: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.sm) {
            Text("Facilitator Matches (\(currentBatch.merchantGroups.count))")
                .font(.subheadline)
                .foregroundColor(ZapColors.textSecondary)
            
            if currentBatch.merchantGroups.isEmpty {
                Text("Finding facilitators to handle your payment rails...")
                    .font(.footnote)
                    .foregroundColor(ZapColors.textSecondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(ZapRadius.small)
            } else {
                ForEach(currentBatch.merchantGroups) { group in
                    MerchantGroupRowView(
                        group: group,
                        isSent: sentGroupIds.contains(group.groupId)
                    )
                }
            }
            
            Text("Orders are grouped by payment method to minimize ZEC transactions.")
                .font(.caption)
                .foregroundColor(ZapColors.textSecondary)
        }
    }
    
    private var ordersSection: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.sm) {
            Text("Recipients (\(currentBatch.orders.count))")
                .font(.subheadline)
                .foregroundColor(ZapColors.textSecondary)
            
            ForEach(currentBatch.orders, id: \.orderId) { order in
                OrderRowView(order: order)
            }
        }
    }
    
    // MARK: - Actions
    
    private func handlePrimaryTap() {
        if allGroupsSent || isCompleted || isFailedOrCancelled {
            onClose()
        } else if !readyToSendGroups.isEmpty {
            Task { await sendZecToReadyGroups() }
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
        
        while isPolling && !allGroupsSent && !isCompleted && !isFailedOrCancelled && !Task.isCancelled {
            do {
                if let updated = try await orderService.getBatchOrder(
                    batchId: currentBatch.batchId,
                    userWalletAddress: walletAddress
                ) {
                    currentBatch = updated
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
    private func sendZecToReadyGroups() async {
        guard !readyToSendGroups.isEmpty else { return }
        
        errorMessage = nil
        isSendingZec = true
        
        for group in readyToSendGroups {
            guard let merchantAddress = group.merchantZecAddress,
                  !merchantAddress.isEmpty else { continue }
            
            do {
                let amountString = try formatZecAmount(group.totalZecAmount)
                _ = try await walletViewModel.send(
                    to: merchantAddress,
                    amount: amountString,
                    memo: "Zapp batch \(currentBatch.batchId) - group \(group.groupId)"
                )
                
                sentGroupIds.insert(group.groupId)
            } catch {
                isSendingZec = false
                if let walletError = error as? WalletError, case .invalidRecipient = walletError {
                    errorMessage = "Invalid facilitator address for group \(group.groupId). Please contact support."
                } else {
                    errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                }
                return
            }
        }
        
        isSendingZec = false
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

// MARK: - Supporting Views

private struct MerchantGroupRowView: View {
    let group: MerchantGroupDTO
    let isSent: Bool
    
    private var statusColor: Color {
        if isSent || group.status == "completed" {
            return .green
        } else if group.status == "fiat_sent" {
            return ZapColors.primary
        } else {
            return ZapColors.textSecondary
        }
    }
    
    private var statusText: String {
        if isSent {
            return "ZEC Sent"
        }
        return group.status.replacingOccurrences(of: "_", with: " ").capitalized
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.xs) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Facilitator \(group.merchantId ?? "Pending")")
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundColor(ZapColors.textPrimary)
                    
                    Text(group.paymentRails.joined(separator: ", ").uppercased())
                        .font(.caption2)
                        .foregroundColor(ZapColors.textSecondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.6f ZEC", group.totalZecAmount))
                        .font(.footnote)
                        .foregroundColor(ZapColors.textPrimary)
                    
                    Text(statusText)
                        .font(.caption2)
                        .foregroundColor(statusColor)
                }
            }
            
            if let address = group.merchantZecAddress, !address.isEmpty {
                Text(address)
                    .font(.caption2)
                    .foregroundColor(ZapColors.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Text("\(group.orderIds.count) order(s)")
                .font(.caption2)
                .foregroundColor(ZapColors.textSecondary)
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(ZapRadius.small)
    }
}

private struct OrderRowView: View {
    let order: ZapOrderDTO
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(order.merchantName ?? order.merchantCode)
                    .font(.footnote)
                    .foregroundColor(ZapColors.textPrimary)
                    .lineLimit(1)
                
                Text(order.merchantCode)
                    .font(.caption2)
                    .foregroundColor(ZapColors.textSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.2f %@", order.fiatAmount, order.fiatCurrency))
                    .font(.footnote)
                    .foregroundColor(ZapColors.textPrimary)
                
                Text(order.status.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption2)
                    .foregroundColor(ZapColors.textSecondary)
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(ZapRadius.small)
    }
}
