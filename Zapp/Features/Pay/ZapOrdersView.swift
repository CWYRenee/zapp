import SwiftUI

struct ZapOrdersView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var walletViewModel: WalletViewModel

    @State private var orders: [ZapOrderDTO] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var isPolling: Bool = true

    private let orderService = ZapOrderService()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: ZapSpacing.base) {
                Text("Zapp Orders")
                    .font(ZapTypography.titleFont)
                    .foregroundColor(ZapColors.primary)

                if let address = walletViewModel.walletInfo?.address {
                    Text(truncated(address))
                        .font(.subheadline)
                        .foregroundColor(ZapColors.textSecondary)
                } else {
                    Text("Wallet not ready yet.")
                        .font(.subheadline)
                        .foregroundColor(ZapColors.textSecondary)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                }

                if isLoading && orders.isEmpty {
                    Spacer()
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    Spacer()
                } else if orders.isEmpty {
                    Spacer()
                    Text("No Zapp orders yet.")
                        .font(ZapTypography.bodyFont)
                        .foregroundColor(ZapColors.textSecondary)
                    Spacer()
                } else {
                    List {
                        ForEach(orders, id: \.orderId) { order in
                            ZapOrderRow(order: order)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .padding(.horizontal, ZapSpacing.xl)
            .padding(.top, ZapSpacing.xl)
            .background(ZapColors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await startPolling()
        }
        .onDisappear {
            isPolling = false
        }
    }

    @MainActor
    private func startPolling() async {
        await walletViewModel.loadWalletIfNeeded()

        guard let walletInfo = walletViewModel.walletInfo else {
            isLoading = false
            errorMessage = "Wallet is not ready. Please wait for sync to complete."
            return
        }

        let address = walletInfo.address

        while isPolling && !Task.isCancelled {
            await fetchOrders(for: address)
            try? await Task.sleep(nanoseconds: 5_000_000_000)
        }
    }

    @MainActor
    private func fetchOrders(for walletAddress: String) async {
        if orders.isEmpty {
            isLoading = true
        }

        do {
            let fetched = try await orderService.listOrdersForUser(
                userWalletAddress: walletAddress,
                status: nil
            )
            orders = fetched
            errorMessage = nil
        } catch {
            if let localized = error as? LocalizedError, let description = localized.errorDescription {
                errorMessage = description
            } else {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    private func truncated(_ address: String) -> String {
        guard address.count > 12 else { return address }
        let prefix = address.prefix(6)
        let suffix = address.suffix(6)
        return "\(prefix)...\(suffix)"
    }
}

struct ZapOrderRow: View {
    let order: ZapOrderDTO

    private var statusText: String {
        order.status.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private var statusColor: Color {
        switch order.status {
        case "pending": return .orange
        case "accepted": return .blue
        case "fiat_sent": return .purple
        case "zec_sent": return .teal
        case "completed": return .green
        case "cancelled": return .gray
        case "failed": return .red
        default: return ZapColors.textSecondary
        }
    }

    private var createdAtText: String? {
        guard let createdAt = order.createdAt,
              let date = ISO8601DateFormatter().date(from: createdAt) else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.xs) {
            HStack(alignment: .top, spacing: ZapSpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(order.merchantName ?? order.merchantCode)
                        .font(.headline)
                        .foregroundColor(ZapColors.textPrimary)

                    Text(order.orderId)
                        .font(.caption)
                        .foregroundColor(ZapColors.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                Text(statusText)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.1))
                    .foregroundColor(statusColor)
                    .clipShape(Capsule())
            }

            HStack(spacing: ZapSpacing.sm) {
                Text(String(format: "%.2f %@", order.fiatAmount, order.fiatCurrency))
                    .font(.subheadline)
                    .foregroundColor(ZapColors.textPrimary)

                Text(String(format: "%.8f ZEC", order.zecAmount))
                    .font(.footnote)
                    .foregroundColor(ZapColors.textSecondary)
            }

            if let created = createdAtText {
                Text(created)
                    .font(.caption)
                    .foregroundColor(ZapColors.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}
