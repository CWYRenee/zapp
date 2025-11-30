import SwiftUI

struct EarnOverviewTab: View {
    @ObservedObject var viewModel: EarnViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ZapSpacing.xl) {
                // Stats Cards
                statsSection
                
                // APY Chart
                apyChartSection
                
                // Protocol Info
                protocolInfoSection
                
                // Bridge Status
                bridgeStatusSection
                
                Spacer(minLength: ZapSpacing.xl)
            }
            .padding(.horizontal, ZapSpacing.xl)
            .padding(.top, ZapSpacing.lg)
        }
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.sm) {
            Text("Your Earnings")
                .font(.headline)
                .foregroundColor(ZapColors.textPrimary)
            
            if let stats = viewModel.userStats {
                HStack(spacing: ZapSpacing.md) {
                    statsCard(
                        title: "Total Deposited",
                        value: String(format: "%.4f ZEC", stats.totalDeposited),
                        icon: "arrow.down.circle.fill",
                        color: .blue
                    )
                    
                    statsCard(
                        title: "Current Value",
                        value: String(format: "%.4f ZEC", stats.totalCurrentValue),
                        icon: "dollarsign.circle.fill",
                        color: ZapColors.primary
                    )
                }
                
                HStack(spacing: ZapSpacing.md) {
                    statsCard(
                        title: "Total Earned",
                        value: String(format: "+%.6f ZEC", stats.totalEarnings),
                        subtitle: String(format: "%.2f%%", stats.earningsPercent),
                        icon: "chart.line.uptrend.xyaxis",
                        color: .green
                    )
                    
                    statsCard(
                        title: "Active Positions",
                        value: "\(stats.activePositions)",
                        icon: "circle.fill",
                        color: .purple
                    )
                }
            } else {
                // Empty state
                HStack(spacing: ZapSpacing.md) {
                    statsCard(
                        title: "Total Deposited",
                        value: "0 ZEC",
                        icon: "arrow.down.circle.fill",
                        color: .blue
                    )
                    
                    statsCard(
                        title: "Total Earned",
                        value: "0 ZEC",
                        icon: "chart.line.uptrend.xyaxis",
                        color: .green
                    )
                }
            }
        }
    }
    
    private func statsCard(
        title: String,
        value: String,
        subtitle: String? = nil,
        icon: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: ZapSpacing.xs) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(ZapColors.textSecondary)
            }
            
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(ZapColors.textPrimary)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.green)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ZapSpacing.md)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(ZapRadius.medium)
    }
    
    // MARK: - APY Chart Section
    
    private var apyChartSection: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.sm) {
            HStack {
                Text("APY History")
                    .font(.headline)
                    .foregroundColor(ZapColors.textPrimary)
                
                Spacer()
                
                if let protocolInfo = viewModel.protocolInfo {
                    Text(protocolInfo.formattedApy)
                        .font(.headline)
                        .foregroundColor(ZapColors.primary)
                }
            }
            
            if !viewModel.apyHistory.isEmpty {
                ApyChart(data: viewModel.apyHistory)
                    .frame(height: 120)
            } else {
                RoundedRectangle(cornerRadius: ZapRadius.medium)
                    .fill(Color(.secondarySystemBackground))
                    .frame(height: 120)
                    .overlay {
                        Text("Loading chart...")
                            .font(.caption)
                            .foregroundColor(ZapColors.textSecondary)
                    }
            }
        }
    }
    
    // MARK: - Protocol Info Section
    
    private var protocolInfoSection: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.sm) {
            Text("Protocol Info")
                .font(.headline)
                .foregroundColor(ZapColors.textPrimary)
            
            if let protocolInfo = viewModel.protocolInfo {
                VStack(spacing: ZapSpacing.sm) {
                    protocolRow(label: "Protocol", value: protocolInfo.protocolName)
                    protocolRow(label: "Current APY", value: protocolInfo.formattedApy, valueColor: ZapColors.primary)
                    protocolRow(label: "Total Value Locked", value: protocolInfo.formattedTvl)
                    protocolRow(label: "Min Deposit", value: "\(protocolInfo.minDeposit) ZEC")
                    protocolRow(label: "Max Deposit", value: "\(protocolInfo.maxDeposit) ZEC")
                    protocolRow(label: "Withdrawal Fee", value: "\(protocolInfo.withdrawalFeePercent)%")
                }
                .padding(ZapSpacing.md)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(ZapRadius.medium)
            }
        }
    }
    
    private func protocolRow(label: String, value: String, valueColor: Color = ZapColors.textPrimary) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(ZapColors.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(valueColor)
        }
    }
    
    // MARK: - Bridge Status Section
    
    private var bridgeStatusSection: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.sm) {
            Text("Bridge Status")
                .font(.headline)
                .foregroundColor(ZapColors.textPrimary)
            
            HStack(spacing: ZapSpacing.md) {
                // Status indicator
                Circle()
                    .fill(viewModel.bridgeHealth?.isOperational == true ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.bridgeHealth?.isOperational == true ? "Operational" : "Unavailable")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ZapColors.textPrimary)
                    
                    if let health = viewModel.bridgeHealth {
                        Text("Est. bridge time: ~\(health.estimatedDelayMinutes) min")
                            .font(.caption)
                            .foregroundColor(ZapColors.textSecondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "arrow.left.arrow.right")
                    .font(.title3)
                    .foregroundColor(ZapColors.textSecondary)
            }
            .padding(ZapSpacing.md)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(ZapRadius.medium)
        }
    }
}

// MARK: - APY Chart

struct ApyChart: View {
    let data: [ApyHistoryPoint]
    
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
                                ZapColors.primary.opacity(0.3),
                                ZapColors.primary.opacity(0.05)
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
                        ZapColors.primary,
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
        
        let apyValues = data.map { $0.apy }
        let minApy = apyValues.min() ?? 0
        let maxApy = apyValues.max() ?? 1
        let range = max(maxApy - minApy, 1)
        
        let stepX = size.width / CGFloat(data.count - 1)
        let padding: CGFloat = 8
        let effectiveHeight = size.height - padding * 2
        
        return data.enumerated().map { index, point in
            let x = CGFloat(index) * stepX
            let normalizedY = (point.apy - minApy) / range
            let y = padding + effectiveHeight * (1 - CGFloat(normalizedY))
            return CGPoint(x: x, y: y)
        }
    }
}

#Preview {
    EarnOverviewTab(
        viewModel: EarnViewModel(
            apiService: EarnAPIService.shared,
            zcashWalletAddress: "zs1test"
        )
    )
}
