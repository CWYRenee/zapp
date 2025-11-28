import SwiftUI
import ZcashLightClientKit

struct HomeView: View {
    @EnvironmentObject private var walletViewModel: WalletViewModel
    @EnvironmentObject private var currencyStore: CurrencyStore
    private let showNavLabels: Bool
    @StateObject private var viewModel: HomeViewModel
    @StateObject private var transactionListVM: TransactionListViewModel
    @State private var activeSheet: ActiveSheet?
    @AppStorage("handPreference") private var handPreference: String = "right"
    @State private var selectedActivityRange: ActivityRange = .day
    @State private var isBalanceExpanded: Bool = false
    @State private var isShowingCurrencySelector: Bool = false
    @State private var expandedTransactionID: Data?
    @State private var expandedOrderID: String?
    @State private var isWordSearchPresented: Bool = false

    private var isRightHanded: Bool { handPreference != "left" }
    
    /// Show word search game while wallet is syncing
    private var shouldShowWordSearchGame: Bool {
        !walletViewModel.isSynced && isWordSearchPresented
    }

    enum ActiveSheet: Identifiable {
        case pay
        case send
        case receive

        var id: Int {
            switch self {
            case .pay: return 0
            case .send: return 1
            case .receive: return 2
            }
        }
    }

    enum ActivityRange: String, CaseIterable, Identifiable {
        case day
        case week
        case month

        var id: String { rawValue }

        var title: String {
            switch self {
            case .day: return "24h"
            case .week: return "1w"
            case .month: return "1m"
            }
        }
    }

    init(
        viewModel: HomeViewModel = HomeViewModel(service: HomeServiceStub()),
        walletViewModel: WalletViewModel,
        showNavLabels: Bool = false
    ) {
        self.showNavLabels = showNavLabels
        _viewModel = StateObject(wrappedValue: viewModel)
        _transactionListVM = StateObject(wrappedValue: TransactionListViewModel(walletViewModel: walletViewModel))
    }

    var body: some View {
        ZStack {
            // Main content
            ScrollView {
                VStack(alignment: .leading, spacing: ZapSpacing.xl) {
                    header
                    balanceSection
                    activitySection
                    recentActivitySection
                    Spacer(minLength: ZapSpacing.xl)
                }
                .padding(.horizontal, ZapSpacing.xl)
                .padding(.top, ZapSpacing.xl)
                .padding(.bottom, 100) // Space for floating buttons
            }
            .background(ZapColors.background.ignoresSafeArea())
            
            // Word search game overlay while wallet is syncing
            if shouldShowWordSearchGame {
                WordSearchGameView(onDismiss: {
                    isWordSearchPresented = false
                })
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .zIndex(1)
            }
        }
        .task {
            await viewModel.refresh()
            await walletViewModel.loadWalletIfNeeded()
            await currencyStore.fetchRates()
            await transactionListVM.loadInitialData()
        }
        .onAppear {
            // Automatically show the game when the wallet view first appears and is still syncing
            if !walletViewModel.isSynced {
                isWordSearchPresented = true
            }
        }
        .refreshable {
            await viewModel.refresh()
            await walletViewModel.reloadWallet()
            await transactionListVM.refresh()
        }
        .onDisappear {
            transactionListVM.stopPolling()
        }
        .onChange(of: walletViewModel.isSynced) { _, isSynced in
            if isSynced {
                withAnimation {
                    isWordSearchPresented = false
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .pay:
                PayView()
            case .send:
                SendView()
            case .receive:
                ReceiveView()
            }
        }
        .sheet(isPresented: $isShowingCurrencySelector) {
            CurrencySelectorView()
        }
        .overlay(alignment: isRightHanded ? .bottomTrailing : .bottomLeading) {
            if !shouldShowWordSearchGame {
                VStack(spacing: 8) {
                // Send
                Button {
                    activeSheet = .send
                } label: {
                    HStack(spacing: ZapSpacing.xs) {
                        if isRightHanded {
                            Text("Send")
                                .font(.caption)
                                .foregroundColor(ZapColors.textPrimary)
                                .frame(width: 64, alignment: .trailing)
                                .padding(.horizontal, ZapSpacing.xs)
                                .padding(.vertical, 4)
                                .background(Color(.systemBackground).opacity(0.9))
                                .cornerRadius(12)
                                .opacity(showNavLabels ? 1 : 0)

                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(ZapColors.primary)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(ZapColors.primary)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)

                            Text("Send")
                                .font(.caption)
                                .foregroundColor(ZapColors.textPrimary)
                                .frame(width: 64, alignment: .leading)
                                .padding(.horizontal, ZapSpacing.xs)
                                .padding(.vertical, 4)
                                .background(Color(.systemBackground).opacity(0.9))
                                .cornerRadius(12)
                                .opacity(showNavLabels ? 1 : 0)
                        }
                    }
                }
                .buttonStyle(.plain)

                // Receive
                Button {
                    activeSheet = .receive
                } label: {
                    HStack(spacing: ZapSpacing.xs) {
                        if isRightHanded {
                            Text("Receive")
                                .font(.caption)
                                .foregroundColor(ZapColors.textPrimary)
                                .frame(width: 64, alignment: .trailing)
                                .padding(.horizontal, ZapSpacing.xs)
                                .padding(.vertical, 4)
                                .background(Color(.systemBackground).opacity(0.9))
                                .cornerRadius(12)
                                .opacity(showNavLabels ? 1 : 0)

                            Image(systemName: "arrow.down.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(ZapColors.primary)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
                        } else {
                            Image(systemName: "arrow.down.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(ZapColors.primary)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)

                            Text("Receive")
                                .font(.caption)
                                .foregroundColor(ZapColors.textPrimary)
                                .frame(width: 64, alignment: .leading)
                                .padding(.horizontal, ZapSpacing.xs)
                                .padding(.vertical, 4)
                                .background(Color(.systemBackground).opacity(0.9))
                                .cornerRadius(12)
                                .opacity(showNavLabels ? 1 : 0)
                        }
                    }
                }
                .buttonStyle(.plain)

                // Pay (bottom)
                Button {
                    activeSheet = .pay
                } label: {
                    HStack(spacing: ZapSpacing.xs) {
                        if isRightHanded {
                            Text("Pay")
                                .font(.caption)
                                .foregroundColor(ZapColors.textPrimary)
                                .frame(width: 64, alignment: .trailing)
                                .padding(.horizontal, ZapSpacing.xs)
                                .padding(.vertical, 4)
                                .background(Color(.systemBackground).opacity(0.9))
                                .cornerRadius(12)
                                .opacity(showNavLabels ? 1 : 0)

                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(ZapColors.primary)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
                        } else {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(ZapColors.primary)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)

                            Text("Pay")
                                .font(.caption)
                                .foregroundColor(ZapColors.textPrimary)
                                .frame(width: 64, alignment: .leading)
                                .padding(.horizontal, ZapSpacing.xs)
                                .padding(.vertical, 4)
                                .background(Color(.systemBackground).opacity(0.9))
                                .cornerRadius(12)
                                .opacity(showNavLabels ? 1 : 0)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, ZapSpacing.xl)
            .padding(.bottom, ZapSpacing.xl)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.sm) {
            // Top row: Wallet title + currency selector
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: ZapSpacing.xs) {
                    Text("Wallet")
                        .font(ZapTypography.titleFont)
                        .foregroundColor(ZapColors.primary)

                    if let address = walletViewModel.walletInfo?.address {
                        Text(truncated(address))
                            .font(.subheadline)
                            .foregroundColor(ZapColors.textSecondary)
                    }
                }
                
                Spacer()
                
                Button {
                    isShowingCurrencySelector = true
                } label: {
                    HStack(spacing: 4) {
                        Text(currencyStore.selectedCurrency.symbol)
                            .font(.headline)
                            .foregroundColor(ZapColors.primary)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(ZapColors.textSecondary)
                    }
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
            
            // Sync progress bar - full width
            if walletViewModel.syncProgress < 1.0 {
                VStack(alignment: .leading, spacing: ZapSpacing.sm) {
                    HStack(spacing: ZapSpacing.sm) {
                        Text(walletViewModel.syncStatusText)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(ZapColors.textSecondary)
                        Spacer()
                        
                        Text("\(Int(walletViewModel.syncProgress * 100))%")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(ZapColors.primary)
                    }
                    
                    // Progress bar - full width
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background track
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.secondarySystemBackground))
                                .frame(width: geometry.size.width, height: 6)
                            
                            // Progress fill with gradient
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            ZapColors.primary,
                                            ZapColors.accent
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * walletViewModel.syncProgress, height: 6)
                                .animation(.easeInOut(duration: 0.3), value: walletViewModel.syncProgress)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 6)
                    
                    // Play word search game button - full width
                    if !walletViewModel.isSynced {
                        Button {
                            withAnimation {
                                isWordSearchPresented = true
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "gamecontroller.fill")
                                    .font(.subheadline)
                                Text("Play Word Search While You Wait")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [ZapColors.primary, ZapColors.accent]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var balanceSection: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.sm) {
            Text("Total Balance")
                .font(.subheadline)
                .foregroundColor(ZapColors.textSecondary)

            if walletViewModel.isLoading {
                ProgressView()
            } else if let error = walletViewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.footnote)
            } else {
                HStack(alignment: .center, spacing: ZapSpacing.sm) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isBalanceExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: ZapSpacing.xs) {
                            if let usd = walletViewModel.totalUsdBalance {
                                Text(currencyStore.convert(usd))
                                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                                    .foregroundColor(ZapColors.textPrimary)
                            } else {
                                Text(walletViewModel.totalZecBalanceText)
                                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                                    .foregroundColor(ZapColors.textPrimary)
                            }

                            Image(systemName: isBalanceExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundColor(ZapColors.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)

                    if let info = walletViewModel.walletInfo, info.transparentBalance > .zero {
                        Button {
                            Task { await walletViewModel.shieldTransparentFunds() }
                        } label: {
                            Image(systemName: "shield.fill")
                                .foregroundColor(ZapColors.primary)
                        }
                        .buttonStyle(.plain)
                        .disabled(walletViewModel.isShieldingTransparentFunds)
                        .overlay {
                            if walletViewModel.isShieldingTransparentFunds {
                                ProgressView()
                                    .progressViewStyle(.circular)
                            }
                        }
                        .help("Shield transparent funds into your shielded balance")
                    }
                }

                if walletViewModel.totalUsdBalance != nil {
                    Text("≈ \(walletViewModel.totalZecBalanceText)")
                        .font(.footnote)
                        .foregroundColor(ZapColors.textSecondary)
                }

                if let info = walletViewModel.walletInfo {
                    BalanceBreakdownView(
                        shieldedSpendable: info.shieldedSpendable,
                        transparent: info.transparentBalance
                    )

                    if isBalanceExpanded {
                        VStack(alignment: .leading, spacing: ZapSpacing.xs) {
                            Text("Shielded (spendable): \(info.shieldedSpendable.tazString()) TAZ")
                                .font(.footnote)
                                .foregroundColor(ZapColors.textSecondary)

                            Text("Transparent: \(info.transparentBalance.tazString()) TAZ")
                                .font(.footnote)
                                .foregroundColor(ZapColors.textSecondary)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    if walletViewModel.isShieldingTransparentFunds {
                        Text("Shielding transparent funds…")
                            .font(.footnote)
                            .foregroundColor(ZapColors.textSecondary)
                    }
                }
            }
        }
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.sm) {
            Text("Activity")
                .font(.headline)
                .foregroundColor(ZapColors.textPrimary)

            // Filter tabs
            HStack(spacing: ZapSpacing.xs) {
                ForEach(TransactionListViewModel.ActivityFilter.allCases) { filter in
                    Button {
                        transactionListVM.selectedFilter = filter
                    } label: {
                        Text(filter.rawValue)
                            .font(.caption)
                            .foregroundColor(transactionListVM.selectedFilter == filter ? ZapColors.primary : ZapColors.textSecondary)
                            .padding(.horizontal, ZapSpacing.sm)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(transactionListVM.selectedFilter == filter ? Color(.secondarySystemBackground) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Range toggles
            HStack(spacing: ZapSpacing.xs) {
                ForEach(ActivityRange.allCases) { range in
                    Button {
                        selectedActivityRange = range
                    } label: {
                        Text(range.title)
                            .font(.caption)
                            .foregroundColor(selectedActivityRange == range ? ZapColors.primary : ZapColors.textSecondary)
                            .padding(.horizontal, ZapSpacing.sm)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(selectedActivityRange == range ? ZapColors.background : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Activity chart with real data
            ActivityChart(
                zapOrders: transactionListVM.zapOrders,
                onChainRows: transactionListVM.onChainRows,
                filter: transactionListVM.selectedFilter,
                range: selectedActivityRange,
                currencyStore: currencyStore
            )
            .frame(height: 120)
        }
    }

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.sm) {
            Text("Recent")
                .font(.headline)
                .foregroundColor(ZapColors.textPrimary)

            if transactionListVM.isLoadingOrders && transactionListVM.zapOrders.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if transactionListVM.zapOrders.isEmpty && transactionListVM.onChainRows.isEmpty {
                Text("No activity yet")
                    .font(.body)
                    .foregroundColor(ZapColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                VStack(spacing: ZapSpacing.sm) {
                    // Show filtered activity
                    if transactionListVM.selectedFilter == .all || transactionListVM.selectedFilter == .zapOrders {
                        ForEach(transactionListVM.zapOrders.prefix(10), id: \.orderId) { order in
                            ZapOrderCompactRow(
                                order: order,
                                isExpanded: expandedOrderID == order.orderId,
                                currencyStore: currencyStore,
                                onTap: {
                                    withAnimation {
                                        expandedOrderID = expandedOrderID == order.orderId ? nil : order.orderId
                                    }
                                }
                            )
                        }
                    }
                    
                    if transactionListVM.selectedFilter == .all || transactionListVM.selectedFilter == .onChain {
                        ForEach(transactionListVM.onChainRows.prefix(10)) { row in
                            OnChainTransactionRow(
                                row: row,
                                isExpanded: expandedTransactionID == row.id,
                                onTap: {
                                    withAnimation {
                                        expandedTransactionID = expandedTransactionID == row.id ? nil : row.id
                                    }
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    private func truncated(_ address: String) -> String {
        guard address.count > 12 else { return address }
        let prefix = address.prefix(6)
        let suffix = address.suffix(6)
        return "\(prefix)...\(suffix)"
    }
}

// MARK: - Activity Chart
struct ActivityChart: View {
    let zapOrders: [ZapOrderDTO]
    let onChainRows: [TransactionListViewModel.TransactionRow]
    let filter: TransactionListViewModel.ActivityFilter
    let range: HomeView.ActivityRange
    let currencyStore: CurrencyStore
    
    var body: some View {
        let data = computeChartData()
        
        VStack(alignment: .leading, spacing: ZapSpacing.xs) {
            if data.values.isEmpty || data.values.allSatisfy({ $0 == 0 }) {
                Text("No activity in this period")
                    .font(.footnote)
                    .foregroundColor(ZapColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                MiniAreaChart(values: data.values)
                    .frame(height: 80)
                
                Text(data.summary)
                    .font(.caption)
                    .foregroundColor(ZapColors.textSecondary)
            }
        }
    }
    
    private func computeChartData() -> (values: [Double], summary: String) {
        let bucketCount: Int
        let totalWindow: TimeInterval
        
        switch range {
        case .day:
            bucketCount = 24
            totalWindow = 24 * 60 * 60
        case .week:
            bucketCount = 7
            totalWindow = 7 * 24 * 60 * 60
        case .month:
            bucketCount = 30
            totalWindow = 30 * 24 * 60 * 60
        }
        
        let now = Date()
        let start = now.addingTimeInterval(-totalWindow)
        let bucketSize = totalWindow / Double(bucketCount)
        var buckets = Array(repeating: 0.0, count: bucketCount)
        
        // Add Zapp Orders
        if filter == .all || filter == .zapOrders {
            for order in zapOrders {
                guard let createdAtString = order.createdAt,
                      let date = ISO8601DateFormatter().date(from: createdAtString) else { continue }
                guard date >= start, date <= now else { continue }
                
                let offset = date.timeIntervalSince(start)
                var index = Int(offset / bucketSize)
                if index < 0 { continue }
                if index >= bucketCount { index = bucketCount - 1 }
                
                let convertedFiat = currencyStore.convert(amount: Decimal(order.fiatAmount), from: order.fiatCurrency, to: currencyStore.selectedCurrency)
                buckets[index] += NSDecimalNumber(decimal: convertedFiat).doubleValue
            }
        }
        
        // Add On-chain transactions (in ZEC, convert to fiat)
        if filter == .all || filter == .onChain {
            for row in onChainRows {
                guard let blockTime = row.overview.blockTime else { continue }
                let date = Date(timeIntervalSince1970: blockTime)
                guard date >= start, date <= now else { continue }
                
                let offset = date.timeIntervalSince(start)
                var index = Int(offset / bucketSize)
                if index < 0 { continue }
                if index >= bucketCount { index = bucketCount - 1 }
                
                // Simple approximation: assume 1 ZEC = some fiat based on current rates
                // This is rough but gives an idea of volume
                let amount = abs(Double(row.overview.value.amount)) / 100_000_000.0 // Convert zatoshi to ZEC
                buckets[index] += amount // Just track ZEC volume for on-chain
            }
        }
        
        let total = buckets.reduce(0, +)
        let summary = filter == .onChain ? 
            "Volume: ~\(String(format: "%.2f", total)) ZEC" :
            "Volume: \(currencyStore.selectedCurrency.symbol)\(String(format: "%.2f", total))"
        
        return (buckets, summary)
    }
}

// MARK: - Chart Components
struct MiniAreaChart: View {
    let values: [Double]
    
    var body: some View {
        GeometryReader { geometry in
            let points = normalizedPoints(in: geometry.size)
            
            ZStack {
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
                                ZapColors.primary.opacity(0.2),
                                ZapColors.primary.opacity(0.0)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
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
    }
    
    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard values.count > 1, let min = values.min(), let max = values.max(), max - min > 0 else {
            let midY = size.height / 2
            return [
                CGPoint(x: 0, y: midY),
                CGPoint(x: size.width, y: midY)
            ]
        }
        let range = max - min
        let stepX = size.width / CGFloat(values.count - 1)
        return values.enumerated().map { index, value in
            let x = CGFloat(index) * stepX
            let normalizedY = (value - min) / range
            let y = size.height * (1 - CGFloat(normalizedY))
            return CGPoint(x: x, y: y)
        }
    }
}

// MARK: - Row Components
struct ZapOrderCompactRow: View {
    let order: ZapOrderDTO
    let isExpanded: Bool
    let currencyStore: CurrencyStore
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.xs) {
            Button(action: onTap) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(order.merchantName ?? order.merchantCode)
                            .font(.headline)
                            .foregroundColor(ZapColors.textPrimary)
                        
                        // Show date/time similar to on-chain transactions
                        if let createdAt = order.createdAt {
                            Text(formatDate(createdAt))
                                .font(.subheadline)
                                .foregroundColor(ZapColors.textSecondary)
                        } else {
                            Text("Zapp Order")
                                .font(.subheadline)
                                .foregroundColor(ZapColors.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        // Show original transaction currency and amount
                        Text(formatOriginalCurrency(order.fiatAmount, currency: order.fiatCurrency))
                            .font(.subheadline)
                            .foregroundColor(ZapColors.textPrimary)
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundColor(ZapColors.textSecondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: ZapSpacing.xs) {
                    HStack {
                        Text("Status")
                            .font(.caption)
                            .foregroundColor(ZapColors.textSecondary)
                        Spacer()
                        Text(order.status.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.caption)
                            .foregroundColor(ZapColors.textPrimary)
                    }
                    
                    HStack {
                        Text("ZEC Amount")
                            .font(.caption)
                            .foregroundColor(ZapColors.textSecondary)
                        Spacer()
                        Text(String(format: "%.8f ZEC", order.zecAmount))
                            .font(.caption)
                            .foregroundColor(ZapColors.textPrimary)
                    }
                    
                    // Show conversion to selected currency if different
                    if order.fiatCurrency != currencyStore.selectedCurrency.rawValue {
                        HStack {
                            Text("In \(currencyStore.selectedCurrency.name)")
                                .font(.caption)
                                .foregroundColor(ZapColors.textSecondary)
                            Spacer()
                            let converted = currencyStore.convert(amount: Decimal(order.fiatAmount), from: order.fiatCurrency, to: currencyStore.selectedCurrency)
                            Text(formatCurrency(converted))
                                .font(.caption)
                                .foregroundColor(ZapColors.textSecondary)
                        }
                    }
                }
                .padding(.vertical, ZapSpacing.xs)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(ZapSpacing.sm)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(ZapRadius.medium)
    }
    
    private func formatOriginalCurrency(_ amount: Double, currency: String) -> String {
        let symbol = getCurrencySymbol(for: currency)
        return "\(symbol)\(String(format: "%.2f", amount))"
    }
    
    private func getCurrencySymbol(for code: String) -> String {
        // Map common currency codes to symbols
        switch code.uppercased() {
        case "USD": return "$"
        case "INR": return "₹"
        case "EUR": return "€"
        case "GBP": return "£"
        case "CNY": return "¥"
        case "JPY": return "¥"
        case "KRW": return "₩"
        case "RUB": return "₽"
        default: return code + " "
        }
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyStore.selectedCurrency.rawValue
        formatter.currencySymbol = currencyStore.selectedCurrency.symbol
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(currencyStore.selectedCurrency.symbol)0.00"
    }
    
    private func formatDate(_ dateString: String) -> String {
        // Try ISO8601 formatter with fractional seconds
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = isoFormatter.date(from: dateString) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd, HH:mm"
            return formatter.string(from: date)
        }
        
        // Fallback: try without fractional seconds
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: dateString) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd, HH:mm"
            return formatter.string(from: date)
        }
        
        // If all parsing fails, return original string
        return dateString
    }
}

struct OnChainTransactionRow: View {
    let row: TransactionListViewModel.TransactionRow
    let isExpanded: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.xs) {
            Button(action: onTap) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.title)
                            .font(.headline)
                            .foregroundColor(ZapColors.textPrimary)
                        Text(row.detail)
                            .font(.subheadline)
                            .foregroundColor(ZapColors.textSecondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(row.amountText)
                            .font(.subheadline)
                            .foregroundColor(row.isOutgoing ? .red : .green)
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundColor(ZapColors.textSecondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: ZapSpacing.xs) {
                    HStack {
                        Text("Block")
                            .font(.caption)
                            .foregroundColor(ZapColors.textSecondary)
                        Spacer()
                        Text(row.overview.minedHeight.map { String($0) } ?? "Pending")
                            .font(.caption)
                            .foregroundColor(ZapColors.textPrimary)
                    }
                }
                .padding(.vertical, ZapSpacing.xs)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(ZapSpacing.sm)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(ZapRadius.medium)
    }
}
