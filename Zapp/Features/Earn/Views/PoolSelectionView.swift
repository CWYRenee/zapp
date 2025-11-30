import SwiftUI

/// A view showing available lending pools with live APYs for selection
struct PoolSelectionView: View {
    @ObservedObject var viewModel: EarnViewModel
    @Binding var isExpanded: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.sm) {
            // Header with selected pool summary
            selectedPoolHeader
            
            // Expandable pool list
            if isExpanded {
                poolList
            }
        }
    }
    
    // MARK: - Selected Pool Header
    
    private var selectedPoolHeader: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isExpanded.toggle()
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Lending Pool")
                        .font(.caption)
                        .foregroundColor(ZapColors.textSecondary)
                    
                    if let pool = viewModel.selectedPool {
                        HStack(spacing: ZapSpacing.sm) {
                            // Pool tokens
                            poolTokensIcon(pool.tokenSymbols)
                            
                            Text(pool.displayName)
                                .font(.headline)
                                .foregroundColor(ZapColors.textPrimary)
                            
                            // APY badge
                            apyBadge(pool.formattedApy, tier: pool.apyTier)
                        }
                    } else {
                        Text("Select a pool")
                            .font(.headline)
                            .foregroundColor(ZapColors.textSecondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(ZapColors.textSecondary)
                    .font(.caption)
            }
            .padding(ZapSpacing.md)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(ZapRadius.medium)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Pool List
    
    private var poolList: some View {
        VStack(spacing: ZapSpacing.xs) {
            if viewModel.isLoadingPools {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading pools...")
                        .font(.caption)
                        .foregroundColor(ZapColors.textSecondary)
                }
                .padding(ZapSpacing.md)
            } else if viewModel.availablePools.isEmpty {
                Text("No pools available")
                    .font(.caption)
                    .foregroundColor(ZapColors.textSecondary)
                    .padding(ZapSpacing.md)
            } else {
                ForEach(viewModel.availablePools) { pool in
                    poolRow(pool)
                }
            }
        }
        .padding(.horizontal, ZapSpacing.xs)
        .padding(.vertical, ZapSpacing.sm)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(ZapRadius.medium)
    }
    
    // MARK: - Pool Row
    
    private func poolRow(_ pool: LendingPool) -> some View {
        Button {
            viewModel.selectPool(pool)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isExpanded = false
            }
        } label: {
            HStack {
                // Pool tokens
                poolTokensIcon(pool.tokenSymbols)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(pool.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ZapColors.textPrimary)
                    
                    Text("TVL: \(pool.formattedTvl)")
                        .font(.caption2)
                        .foregroundColor(ZapColors.textSecondary)
                }
                
                Spacer()
                
                // APY
                VStack(alignment: .trailing, spacing: 2) {
                    apyBadge(pool.formattedApy, tier: pool.apyTier)
                    
                    Text("APY")
                        .font(.caption2)
                        .foregroundColor(ZapColors.textSecondary)
                }
                
                // Selection indicator
                if viewModel.selectedPool?.id == pool.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(ZapColors.primary)
                        .font(.body)
                }
            }
            .padding(ZapSpacing.sm)
            .background(
                viewModel.selectedPool?.id == pool.id
                    ? ZapColors.primary.opacity(0.1)
                    : Color.clear
            )
            .cornerRadius(ZapRadius.small)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Helper Views
    
    private func poolTokensIcon(_ symbols: [String]) -> some View {
        HStack(spacing: -8) {
            ForEach(Array(symbols.prefix(2).enumerated()), id: \.offset) { index, symbol in
                ZStack {
                    Circle()
                        .fill(tokenColor(for: symbol))
                        .frame(width: 28, height: 28)
                    
                    Text(String(symbol.prefix(1)))
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .zIndex(Double(symbols.count - index))
            }
        }
    }
    
    private func tokenColor(for symbol: String) -> Color {
        // Assign consistent colors based on token symbol
        let colors: [Color] = [.blue, .purple, .orange, .green, .pink, .cyan]
        let hash = symbol.hashValue
        let index = abs(hash) % colors.count
        return colors[index]
    }
    
    private func apyBadge(_ apy: String, tier: LendingPool.ApyTier) -> some View {
        Text(apy)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(apyColor(tier))
            .padding(.horizontal, ZapSpacing.xs)
            .padding(.vertical, 2)
            .background(apyColor(tier).opacity(0.15))
            .cornerRadius(ZapRadius.small)
    }
    
    private func apyColor(_ tier: LendingPool.ApyTier) -> Color {
        switch tier {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .green
        case .veryHigh: return .orange
        }
    }
}

// MARK: - Compact Pool Card (for summary display)

struct SelectedPoolCard: View {
    let pool: LendingPool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                // Token icons
                HStack(spacing: -6) {
                    ForEach(Array(pool.tokenSymbols.prefix(2).enumerated()), id: \.offset) { index, symbol in
                        ZStack {
                            Circle()
                                .fill(tokenColor(for: symbol))
                                .frame(width: 24, height: 24)
                            
                            Text(String(symbol.prefix(1)))
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(pool.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ZapColors.textPrimary)
                    
                    Text("RHEA Finance")
                        .font(.caption2)
                        .foregroundColor(ZapColors.textSecondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(pool.formattedApy)
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    Text("APY")
                        .font(.caption2)
                        .foregroundColor(ZapColors.textSecondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(ZapColors.textSecondary)
            }
            .padding(ZapSpacing.md)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(ZapRadius.medium)
        }
        .buttonStyle(.plain)
    }
    
    private func tokenColor(for symbol: String) -> Color {
        let colors: [Color] = [.blue, .purple, .orange, .green, .pink, .cyan]
        let hash = symbol.hashValue
        let index = abs(hash) % colors.count
        return colors[index]
    }
}

#Preview {
    VStack {
        PoolSelectionView(
            viewModel: EarnViewModel(
                apiService: EarnAPIService.shared,
                zcashWalletAddress: "zs1test"
            ),
            isExpanded: .constant(true)
        )
        .padding()
    }
    .background(ZapColors.background)
}
