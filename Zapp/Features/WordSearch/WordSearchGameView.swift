import SwiftUI
import Combine
import ZcashLightClientKit

/// Display mode for the word search game
enum WordSearchDisplayMode {
    /// Shown during wallet sync with progress bar
    case syncing
    /// Standalone mode accessible from settings
    case standalone
}

/// Main word search game view displayed during wallet sync or standalone
struct WordSearchGameView: View {
    @StateObject private var viewModel = WordSearchViewModel()
    @EnvironmentObject private var walletViewModel: WalletViewModel
    
    let displayMode: WordSearchDisplayMode
    let onDismiss: (() -> Void)?
    
    init(displayMode: WordSearchDisplayMode = .syncing, onDismiss: (() -> Void)? = nil) {
        self.displayMode = displayMode
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        VStack(spacing: ZapSpacing.lg) {
            // Header with sync progress
            headerSection
            
            // Word list to find
            wordListSection
            
            // The grid
            gridSection
            
            // Instructions
            instructionsSection
        }
        .padding(ZapSpacing.base)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ZapColors.background.ignoresSafeArea())
        .overlay {
            if viewModel.showDefinition, let word = viewModel.foundWord {
                definitionPopup(for: word)
            }
        }
        .overlay {
            if viewModel.isGameComplete && !viewModel.showDefinition {
                gameCompleteOverlay
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: ZapSpacing.xs) {
                    Text(headerTitle)
                        .font(ZapTypography.titleFont)
                        .foregroundColor(ZapColors.primary)
                    
                    Text(headerSubtitle)
                        .font(.subheadline)
                        .foregroundColor(ZapColors.textSecondary)
                }
                
                Spacer()
                
                // New puzzle button
                Button {
                    withAnimation {
                        viewModel.generateNewPuzzle()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                        .foregroundColor(ZapColors.primary)
                        .frame(width: 44, height: 44)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Circle())
                }
                
                // Dismiss button
                if let onDismiss = onDismiss {
                    Button {
                        withAnimation {
                            onDismiss()
                        }
                    } label: {
                        Image(systemName: dismissButtonIcon)
                            .font(.title3)
                            .foregroundColor(ZapColors.textSecondary)
                            .frame(width: 44, height: 44)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Circle())
                    }
                }
            }
            
            // Sync progress (only shown during syncing mode)
            if displayMode == .syncing {
                syncProgressBar
            }
        }
    }
    
    private var headerTitle: String {
        switch displayMode {
        case .syncing:
            return "Your Wallet is Syncing"
        case .standalone:
            return "Word Search"
        }
    }
    
    private var headerSubtitle: String {
        switch displayMode {
        case .syncing:
            return "Play this word search while you wait!"
        case .standalone:
            return "Learn crypto terms while having fun!"
        }
    }
    
    private var dismissButtonIcon: String {
        switch displayMode {
        case .syncing:
            return "wallet.pass"
        case .standalone:
            return "xmark"
        }
    }
    
    private var syncProgressBar: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.xs) {
            HStack {
                Text("Wallet Syncing...")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(ZapColors.textSecondary)
                
                Spacer()
                
                Text("\(Int(walletViewModel.syncProgress * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(ZapColors.primary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.secondarySystemBackground))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [ZapColors.primary, ZapColors.accent]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * walletViewModel.syncProgress, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: walletViewModel.syncProgress)
                }
            }
            .frame(height: 6)
        }
    }
    
    // MARK: - Word List
    
    private var wordListSection: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.xs) {
            Text("Find these words:")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(ZapColors.textSecondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ZapSpacing.sm) {
                    ForEach(viewModel.placedWords) { placedWord in
                        Text(placedWord.word.word)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(placedWord.isFound ? .white : ZapColors.textPrimary)
                            .padding(.horizontal, ZapSpacing.sm)
                            .padding(.vertical, ZapSpacing.xs)
                            .background(
                                RoundedRectangle(cornerRadius: ZapRadius.small)
                                    .fill(placedWord.isFound ? ZapColors.primary : Color(.secondarySystemBackground))
                            )
                            .strikethrough(placedWord.isFound, color: .white)
                    }
                }
            }
        }
    }
    
    // MARK: - Grid
    
    private var gridSection: some View {
        GeometryReader { geometry in
            let cellSize = min(
                (geometry.size.width - CGFloat(viewModel.gridSize - 1) * 2) / CGFloat(viewModel.gridSize),
                (geometry.size.height - CGFloat(viewModel.gridSize - 1) * 2) / CGFloat(viewModel.gridSize)
            )
            
            VStack(spacing: 2) {
                ForEach(0..<viewModel.gridSize, id: \.self) { row in
                    HStack(spacing: 2) {
                        ForEach(0..<viewModel.gridSize, id: \.self) { col in
                            let cell = viewModel.grid[row][col]
                            cellView(cell: cell, size: cellSize)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleDrag(at: value.location, in: geometry.size, cellSize: cellSize)
                    }
                    .onEnded { _ in
                        viewModel.endSelection()
                    }
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .background(
            RoundedRectangle(cornerRadius: ZapRadius.medium)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private func cellView(cell: GridCell, size: CGFloat) -> some View {
        Text(String(cell.letter))
            .font(.system(size: size * 0.5, weight: .bold, design: .monospaced))
            .foregroundColor(cellTextColor(for: cell))
            .frame(width: size, height: size)
            .background(cellBackground(for: cell))
            .cornerRadius(4)
    }
    
    private func cellTextColor(for cell: GridCell) -> Color {
        if cell.isFound {
            return .white
        } else if cell.isSelected {
            return .white
        }
        return ZapColors.textPrimary
    }
    
    private func cellBackground(for cell: GridCell) -> some View {
        Group {
            if cell.isFound {
                viewModel.colorForFoundWord(cell.foundWordId)
            } else if cell.isSelected {
                ZapColors.primary.opacity(0.7)
            } else {
                Color(.tertiarySystemBackground)
            }
        }
    }
    
    private func handleDrag(at location: CGPoint, in size: CGSize, cellSize: CGFloat) {
        let totalGridWidth = CGFloat(viewModel.gridSize) * cellSize + CGFloat(viewModel.gridSize - 1) * 2
        let totalGridHeight = totalGridWidth
        
        let offsetX = (size.width - totalGridWidth) / 2
        let offsetY = (size.height - totalGridHeight) / 2
        
        let adjustedX = location.x - offsetX
        let adjustedY = location.y - offsetY
        
        let col = Int(adjustedX / (cellSize + 2))
        let row = Int(adjustedY / (cellSize + 2))
        
        viewModel.selectCell(at: row, col: col)
    }
    
    // MARK: - Instructions
    
    private var instructionsSection: some View {
        Text("Drag across letters to select words. Words can be horizontal, vertical, or diagonal.")
            .font(.caption)
            .foregroundColor(ZapColors.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
    }
    
    // MARK: - Definition Popup
    
    private func definitionPopup(for word: CypherpunkWord) -> some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        viewModel.dismissDefinition()
                    }
                }
            
            VStack(spacing: ZapSpacing.lg) {
                // Word title
                Text(word.word)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ZapColors.primary)
                
                // Definition
                Text(word.definition)
                    .font(.body)
                    .foregroundColor(ZapColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Dismiss button
                Button {
                    withAnimation {
                        viewModel.dismissDefinition()
                    }
                } label: {
                    Text("Got it!")
                        .font(ZapTypography.buttonFont)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ZapSpacing.md)
                        .background(ZapColors.primary)
                        .cornerRadius(ZapRadius.medium)
                }
            }
            .padding(ZapSpacing.xl)
            .background(
                RoundedRectangle(cornerRadius: ZapRadius.large)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, ZapSpacing.xl)
            .transition(.scale.combined(with: .opacity))
        }
    }
    
    // MARK: - Game Complete Overlay
    
    private var gameCompleteOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: ZapSpacing.lg) {
                Image(systemName: "star.fill")
                    .font(.system(size: 60))
                    .foregroundColor(ZapColors.primary)
                
                Text("Puzzle Complete!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(ZapColors.textPrimary)
                
                Text("You found all \(viewModel.placedWords.count) words!")
                    .font(.body)
                    .foregroundColor(ZapColors.textSecondary)
                
                Button {
                    withAnimation {
                        viewModel.generateNewPuzzle()
                    }
                } label: {
                    Text("New Puzzle")
                        .font(ZapTypography.buttonFont)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ZapSpacing.md)
                        .background(ZapColors.primary)
                        .cornerRadius(ZapRadius.medium)
                }
            }
            .padding(ZapSpacing.xl)
            .background(
                RoundedRectangle(cornerRadius: ZapRadius.large)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, ZapSpacing.xl)
        }
    }
}

// MARK: - Preview

#Preview("Syncing Mode") {
    WordSearchGameView(displayMode: .syncing)
        .environmentObject(WalletViewModel(walletService: MockWalletService()))
}

#Preview("Standalone Mode") {
    WordSearchGameView(displayMode: .standalone, onDismiss: {})
        .environmentObject(WalletViewModel(walletService: MockWalletService()))
}

/// Mock wallet service for previews
private class MockWalletService: WalletServicing {
    func initializeWalletIfNeeded() async throws -> WalletInfo {
        fatalError("Not implemented for preview")
    }
    
    var syncStatePublisher: AnyPublisher<WalletSyncState, Never> {
        Just(WalletSyncState(statusText: "Syncing 45%", progress: 0.45, isSynced: false, areFundsSpendable: false))
            .eraseToAnyPublisher()
    }
    
    func resetWallet() async throws {}
    func loadTransactionsPage(page: Int) async throws -> WalletTransactionsPage {
        fatalError("Not implemented for preview")
    }
    func loadMemos(for rawID: Data) async throws -> [ZcashLightClientKit.Memo] {
        fatalError("Not implemented for preview")
    }
    func send(to address: String, amount: String, memo: String?) async throws -> Data {
        fatalError("Not implemented for preview")
    }
    func shieldTransparentFunds() async throws {}
}
