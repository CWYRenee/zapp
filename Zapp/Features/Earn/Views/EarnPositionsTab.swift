import SwiftUI

struct EarnPositionsTab: View {
    @ObservedObject var viewModel: EarnViewModel
    @State private var selectedPositionForDetail: EarnPositionSummary?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ZapSpacing.xl) {
                // Active Positions
                if !viewModel.activePositions.isEmpty {
                    positionsSection(
                        title: "Active Positions",
                        positions: viewModel.activePositions,
                        emptyMessage: nil
                    )
                }
                
                // In Progress
                if !viewModel.inProgressPositions.isEmpty {
                    positionsSection(
                        title: "In Progress",
                        positions: viewModel.inProgressPositions,
                        emptyMessage: nil
                    )
                }
                
                // Completed
                if !viewModel.completedPositions.isEmpty {
                    positionsSection(
                        title: "Completed",
                        positions: viewModel.completedPositions,
                        emptyMessage: nil
                    )
                }
                
                // Empty State
                if viewModel.positions.isEmpty {
                    emptyStateView
                }
                
                Spacer(minLength: ZapSpacing.xl)
            }
            .padding(.horizontal, ZapSpacing.xl)
            .padding(.top, ZapSpacing.lg)
        }
        .sheet(item: $selectedPositionForDetail) { position in
            PositionDetailSheet(viewModel: viewModel, position: position)
        }
    }
    
    // MARK: - Positions Section
    
    private func positionsSection(
        title: String,
        positions: [EarnPositionSummary],
        emptyMessage: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: ZapSpacing.sm) {
            Text(title)
                .font(.headline)
                .foregroundColor(ZapColors.textPrimary)
            
            if positions.isEmpty, let message = emptyMessage {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(ZapColors.textSecondary)
                    .padding(ZapSpacing.md)
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(ZapRadius.medium)
            } else {
                VStack(spacing: ZapSpacing.sm) {
                    ForEach(positions) { position in
                        PositionCard(position: position) {
                            selectedPositionForDetail = position
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: ZapSpacing.lg) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(ZapColors.textSecondary)
            
            Text("No Positions Yet")
                .font(.headline)
                .foregroundColor(ZapColors.textPrimary)
            
            Text("Start earning by depositing ZEC to the lending protocol.")
                .font(.subheadline)
                .foregroundColor(ZapColors.textSecondary)
                .multilineTextAlignment(.center)
            
            Button {
                viewModel.currentTab = .deposit
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Make Your First Deposit")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(ZapColors.primary)
            }
        }
        .padding(ZapSpacing.xl)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Position Card

struct PositionCard: View {
    let position: EarnPositionSummary
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: ZapSpacing.sm) {
                // Header
                HStack {
                    // Status Badge
                    statusBadge
                    
                    Spacer()
                    
                    // Right side info based on status
                    rightSideInfo
                }
                
                // Values
                valueDisplay
                
                // Status-specific content
                statusContent
                
                // Footer
                footerInfo
            }
            .padding(ZapSpacing.md)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(ZapRadius.medium)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Status Badge
    
    private var statusBadge: some View {
        HStack(spacing: 4) {
            if position.status.isInProgress {
                ProgressView()
                    .scaleEffect(0.6)
            } else {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
            }
            
            Text(position.status.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(statusColor)
        }
    }
    
    // MARK: - Right Side Info
    
    @ViewBuilder
    private var rightSideInfo: some View {
        switch position.status {
        case .lendingActive:
            Text(String(format: "%.2f%% APY", position.currentApy))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(ZapColors.primary)
                .padding(.horizontal, ZapSpacing.sm)
                .padding(.vertical, 2)
                .background(ZapColors.primary.opacity(0.1))
                .cornerRadius(ZapRadius.small)
        case .completed:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                Text("Completed")
                    .foregroundColor(.blue)
            }
            .font(.caption)
            .fontWeight(.medium)
        default:
            EmptyView()
        }
    }
    
    // MARK: - Value Display
    
    private var valueDisplay: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(position.status == .completed ? "Final Value" : "Current Value")
                    .font(.caption)
                    .foregroundColor(ZapColors.textSecondary)
                Text(String(format: "%.6f ZEC", position.currentValue))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(ZapColors.textPrimary)
            }
            
            Spacer()
            
            // Show earnings for active/completed
            if position.accruedEarnings > 0 && (position.status.isActive || position.status == .completed) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(position.status == .completed ? "Total Earned" : "Earnings")
                        .font(.caption)
                        .foregroundColor(ZapColors.textSecondary)
                    Text(String(format: "+%.6f", position.accruedEarnings))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
            }
        }
    }
    
    // MARK: - Status Content
    
    @ViewBuilder
    private var statusContent: some View {
        switch position.status {
        case .pendingDeposit:
            progressRow(text: "Waiting for ZEC deposit...", color: .orange)
        case .bridgingToNear:
            progressRow(text: "Bridging to NEAR...", color: .orange)
        case .bridgingToZcash:
            progressRow(text: "Withdrawing to Zcash...", color: .orange)
        case .completed:
            if let completedAt = position.completedAt {
                HStack(spacing: ZapSpacing.xs) {
                    Image(systemName: "calendar")
                        .foregroundColor(ZapColors.textSecondary)
                    Text("Completed \(formatRelativeDate(completedAt))")
                        .font(.caption)
                        .foregroundColor(ZapColors.textSecondary)
                }
            }
        case .failed:
            progressRow(text: "Transaction failed", color: .red)
        default:
            EmptyView()
        }
    }
    
    private func progressRow(text: String, color: Color) -> some View {
        HStack(spacing: ZapSpacing.sm) {
            Text(text)
                .font(.caption)
                .foregroundColor(ZapColors.textSecondary)
        }
        .padding(.vertical, ZapSpacing.xs)
    }
    
    // MARK: - Footer Info
    
    private var footerInfo: some View {
        HStack {
            Text("Deposited: \(String(format: "%.4f ZEC", position.zecDeposited))")
                .font(.caption)
                .foregroundColor(ZapColors.textSecondary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(ZapColors.textSecondary)
        }
    }
    
    // MARK: - Helpers
    
    private var statusColor: Color {
        switch position.status {
        case .lendingActive:
            return .green
        case .completed:
            return .blue
        case .failed, .cancelled:
            return .red
        default:
            return .orange
        }
    }
    
    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Position Detail Sheet

struct PositionDetailSheet: View {
    @ObservedObject var viewModel: EarnViewModel
    let position: EarnPositionSummary
    @Environment(\.dismiss) private var dismiss
    @State private var showWithdrawConfirmation: Bool = false
    @AppStorage("handPreference") private var handPreference: String = "right"
    
    private var isRightHanded: Bool { handPreference != "left" }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: ZapSpacing.xl) {
                        // Status Header
                        statusHeader
                        
                        // Value Section
                        valueSection
                        
                        // Earnings Chart (if active)
                        if position.status.isActive {
                            earningsChartSection
                        }
                        
                        // Details Section
                        detailsSection
                        
                        // Actions based on status
                        if position.status.isActive {
                            actionsSection
                        } else if position.status == .completed {
                            completedSection
                        }
                        
                        Spacer(minLength: ZapSpacing.xl)
                    }
                    .padding(.horizontal, ZapSpacing.xl)
                    .padding(.top, ZapSpacing.lg)
                }
                
                bottomCloseButton
            }
            .navigationTitle("Position Details")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.selectPosition(position)
            }
            .alert("Confirm Withdrawal", isPresented: $showWithdrawConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Withdraw") {
                    Task {
                        await viewModel.initiateWithdrawal(position: position)
                        dismiss()
                    }
                }
            } message: {
                Text("Withdraw \(String(format: "%.6f ZEC", position.currentValue)) including earnings back to your wallet?")
            }
        }
    }
    
    // MARK: - Status Header
    
    private var statusHeader: some View {
        VStack(spacing: ZapSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Status")
                        .font(.caption)
                        .foregroundColor(ZapColors.textSecondary)
                    
                    HStack(spacing: 6) {
                        if position.status.isInProgress {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 10, height: 10)
                        }
                        
                        Text(position.status.displayName)
                            .font(.headline)
                            .foregroundColor(ZapColors.textPrimary)
                    }
                }
                
                Spacer()
                
                // Right side based on status
                statusHeaderRight
            }
            
            // Status-specific message
            if let message = statusMessage {
                HStack(spacing: ZapSpacing.xs) {
                    Image(systemName: statusMessageIcon)
                        .foregroundColor(statusColor)
                    Text(message)
                        .font(.caption)
                        .foregroundColor(ZapColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(ZapSpacing.sm)
                .background(statusColor.opacity(0.1))
                .cornerRadius(ZapRadius.small)
            }
        }
        .padding(ZapSpacing.md)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(ZapRadius.medium)
    }
    
    @ViewBuilder
    private var statusHeaderRight: some View {
        switch position.status {
        case .lendingActive:
            VStack(alignment: .trailing, spacing: 2) {
                Text("Current APY")
                    .font(.caption)
                    .foregroundColor(ZapColors.textSecondary)
                
                Text(String(format: "%.2f%%", position.currentApy))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ZapColors.primary)
            }
        case .completed:
            VStack(alignment: .trailing, spacing: 2) {
                Text("Total Return")
                    .font(.caption)
                    .foregroundColor(ZapColors.textSecondary)
                
                Text(String(format: "+%.2f%%", position.earningsPercent))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
        default:
            EmptyView()
        }
    }
    
    private var statusMessage: String? {
        switch position.status {
        case .pendingDeposit:
            return "Waiting for your ZEC deposit to be confirmed"
        case .bridgingToNear:
            return "Your ZEC is being bridged to NEAR. This may take a few minutes."
        case .bridgingToZcash:
            return "Withdrawing funds back to your Zcash wallet"
        case .completed:
            return "Funds successfully returned to your wallet"
        case .failed:
            return "Transaction failed. Please contact support."
        default:
            return nil
        }
    }
    
    private var statusMessageIcon: String {
        switch position.status {
        case .pendingDeposit, .bridgingToNear, .bridgingToZcash:
            return "clock.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        default:
            return "info.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch position.status {
        case .lendingActive: return .green
        case .completed: return .blue
        case .failed, .cancelled: return .red
        default: return .orange
        }
    }
    
    // MARK: - Value Section
    
    private var valueSection: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.sm) {
            Text("Position Value")
                .font(.headline)
                .foregroundColor(ZapColors.textPrimary)
            
            VStack(spacing: ZapSpacing.sm) {
                valueRow(label: "Original Deposit", value: String(format: "%.6f ZEC", position.zecDeposited))
                valueRow(label: "Current Value", value: String(format: "%.6f ZEC", position.currentValue), isBold: true)
                
                Divider()
                
                valueRow(
                    label: "Total Earnings",
                    value: String(format: "+%.6f ZEC", position.accruedEarnings),
                    valueColor: .green
                )
                valueRow(
                    label: "Earnings %",
                    value: String(format: "+%.2f%%", position.earningsPercent),
                    valueColor: .green
                )
            }
            .padding(ZapSpacing.md)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(ZapRadius.medium)
        }
    }
    
    private func valueRow(
        label: String,
        value: String,
        valueColor: Color = ZapColors.textPrimary,
        isBold: Bool = false
    ) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(ZapColors.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(isBold ? .semibold : .regular)
                .foregroundColor(valueColor)
        }
    }
    
    // MARK: - Earnings Chart Section
    
    private var earningsChartSection: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.sm) {
            Text("Earnings History")
                .font(.headline)
                .foregroundColor(ZapColors.textPrimary)
            
            if !viewModel.positionEarningsHistory.isEmpty {
                EarningsChart(data: viewModel.positionEarningsHistory)
                    .frame(height: 150)
            } else {
                RoundedRectangle(cornerRadius: ZapRadius.medium)
                    .fill(Color(.secondarySystemBackground))
                    .frame(height: 150)
                    .overlay {
                        ProgressView()
                    }
            }
        }
    }
    
    // MARK: - Details Section
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.sm) {
            Text("Details")
                .font(.headline)
                .foregroundColor(ZapColors.textPrimary)
            
            VStack(spacing: ZapSpacing.sm) {
                detailRow(label: "Position ID", value: position.positionId)
                
                if let depositedAt = position.depositedAt {
                    detailRow(label: "Started", value: formatDate(depositedAt))
                }
                
                detailRow(label: "Last Updated", value: formatDate(position.lastUpdatedAt))
            }
            .padding(ZapSpacing.md)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(ZapRadius.medium)
        }
    }
    
    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(ZapColors.textSecondary)
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundColor(ZapColors.textPrimary)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        VStack(spacing: ZapSpacing.sm) {
            ZapButton(
                "Withdraw to Wallet",
                style: .primary,
                isLoading: viewModel.isWithdrawing
            ) {
                showWithdrawConfirmation = true
            }
            
            Text("Funds will be returned to your Zcash address")
                .font(.caption)
                .foregroundColor(ZapColors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Completed Section
    
    private var completedSection: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.sm) {
            Text("Withdrawal Complete")
                .font(.headline)
                .foregroundColor(ZapColors.textPrimary)
            
            VStack(spacing: ZapSpacing.sm) {
                HStack(spacing: ZapSpacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Funds Returned")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(ZapColors.textPrimary)
                        Text(String(format: "%.6f ZEC sent to your wallet", position.currentValue))
                            .font(.caption)
                            .foregroundColor(ZapColors.textSecondary)
                    }
                    
                    Spacer()
                }
                
                if let completedAt = position.completedAt {
                    Divider()
                    
                    HStack {
                        Text("Completed")
                            .font(.caption)
                            .foregroundColor(ZapColors.textSecondary)
                        Spacer()
                        Text(formatDate(completedAt))
                            .font(.caption)
                            .foregroundColor(ZapColors.textPrimary)
                    }
                }
            }
            .padding(ZapSpacing.md)
            .background(Color.green.opacity(0.1))
            .cornerRadius(ZapRadius.medium)
        }
    }
    
    private var bottomCloseButton: some View {
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
}

// MARK: - Earnings Chart

struct EarningsChart: View {
    let data: [EarningsHistoryPoint]
    
    var body: some View {
        GeometryReader { geometry in
            let points = normalizedPoints(in: geometry.size)
            
            ZStack {
                // Area fill
                if points.count > 1 {
                    Path { path in
                        guard let first = points.first, let last = points.last else { return }
                        path.move(to: CGPoint(x: first.x, y: geometry.size.height))
                        for point in points {
                            path.addLine(to: point)
                        }
                        path.addLine(to: CGPoint(x: last.x, y: geometry.size.height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.green.opacity(0.3),
                                Color.green.opacity(0.05)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    // Line
                    Path { path in
                        guard let first = points.first else { return }
                        path.move(to: first)
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(
                        Color.green,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )
                }
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(ZapRadius.medium)
    }
    
    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard data.count > 1 else { return [] }
        
        let balances = data.map { $0.balance }
        let minBal = balances.min() ?? 0
        let maxBal = balances.max() ?? 1
        let range = max(maxBal - minBal, 0.000001)
        
        let stepX = size.width / CGFloat(data.count - 1)
        let padding: CGFloat = 8
        let effectiveHeight = size.height - padding * 2
        
        return data.enumerated().map { index, point in
            let x = CGFloat(index) * stepX
            let normalizedY = (point.balance - minBal) / range
            let y = padding + effectiveHeight * (1 - CGFloat(normalizedY))
            return CGPoint(x: x, y: y)
        }
    }
}

#Preview {
    EarnPositionsTab(
        viewModel: EarnViewModel(
            apiService: EarnAPIService.shared,
            zcashWalletAddress: "zs1test"
        )
    )
}
