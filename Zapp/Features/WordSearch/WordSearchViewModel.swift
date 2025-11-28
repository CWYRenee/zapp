import Foundation
import SwiftUI
import Combine

/// Represents a cell in the word search grid
struct GridCell: Identifiable, Equatable {
    let id = UUID()
    let row: Int
    let col: Int
    let letter: Character
    var isSelected: Bool = false
    var isFound: Bool = false
    var foundWordId: UUID? = nil
}

/// Represents a placed word in the grid
struct PlacedWord: Identifiable {
    let id = UUID()
    let word: CypherpunkWord
    let startRow: Int
    let startCol: Int
    let direction: WordDirection
    var isFound: Bool = false
    
    var cells: [(row: Int, col: Int)] {
        var result: [(Int, Int)] = []
        for i in 0..<word.cleanedWord.count {
            let row = startRow + (direction.rowDelta * i)
            let col = startCol + (direction.colDelta * i)
            result.append((row, col))
        }
        return result
    }
}

/// Direction a word can be placed in the grid
enum WordDirection: CaseIterable {
    case horizontal
    case vertical
    case diagonalDown
    case diagonalUp
    case horizontalReverse
    case verticalReverse
    case diagonalDownReverse
    case diagonalUpReverse
    
    var rowDelta: Int {
        switch self {
        case .horizontal, .horizontalReverse: return 0
        case .vertical: return 1
        case .verticalReverse: return -1
        case .diagonalDown: return 1
        case .diagonalDownReverse: return -1
        case .diagonalUp: return -1
        case .diagonalUpReverse: return 1
        }
    }
    
    var colDelta: Int {
        switch self {
        case .horizontal: return 1
        case .horizontalReverse: return -1
        case .vertical, .verticalReverse: return 0
        case .diagonalDown, .diagonalUp: return 1
        case .diagonalDownReverse, .diagonalUpReverse: return -1
        }
    }
}

@MainActor
final class WordSearchViewModel: ObservableObject {
    @Published var grid: [[GridCell]] = []
    @Published var placedWords: [PlacedWord] = []
    @Published var selectedCells: [GridCell] = []
    @Published var foundWord: CypherpunkWord? = nil
    @Published var showDefinition: Bool = false
    @Published var wordsFound: Int = 0
    @Published var isGameComplete: Bool = false
    
    let gridSize: Int
    private let wordCount: Int
    
    init(gridSize: Int = 10, wordCount: Int = 6) {
        self.gridSize = gridSize
        self.wordCount = wordCount
        generateNewPuzzle()
    }
    
    /// Generate a new word search puzzle
    func generateNewPuzzle() {
        // Reset state
        selectedCells = []
        foundWord = nil
        showDefinition = false
        wordsFound = 0
        isGameComplete = false
        placedWords = []
        
        // Initialize empty grid
        var newGrid: [[GridCell]] = []
        for row in 0..<gridSize {
            var gridRow: [GridCell] = []
            for col in 0..<gridSize {
                gridRow.append(GridCell(row: row, col: col, letter: " "))
            }
            newGrid.append(gridRow)
        }
        
        // Get random words that fit in the grid
        let words = WordSearchData.randomWords(count: wordCount)
            .filter { $0.cleanedWord.count <= gridSize }
        
        // Place words in grid
        for word in words {
            if let placed = placeWord(word, in: &newGrid) {
                placedWords.append(placed)
            }
        }
        
        // Fill remaining cells with random letters
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                if newGrid[row][col].letter == " " {
                    let randomLetter = letters.randomElement()!
                    newGrid[row][col] = GridCell(row: row, col: col, letter: randomLetter)
                }
            }
        }
        
        grid = newGrid
    }
    
    /// Attempt to place a word in the grid
    private func placeWord(_ word: CypherpunkWord, in grid: inout [[GridCell]]) -> PlacedWord? {
        let cleanedWord = word.cleanedWord
        let directions = WordDirection.allCases.shuffled()
        
        // Try random positions and directions
        for _ in 0..<100 {
            let direction = directions.randomElement()!
            let startRow = Int.random(in: 0..<gridSize)
            let startCol = Int.random(in: 0..<gridSize)
            
            if canPlace(cleanedWord, at: startRow, col: startCol, direction: direction, in: grid) {
                // Place the word
                for (i, char) in cleanedWord.enumerated() {
                    let row = startRow + (direction.rowDelta * i)
                    let col = startCol + (direction.colDelta * i)
                    grid[row][col] = GridCell(row: row, col: col, letter: char)
                }
                return PlacedWord(word: word, startRow: startRow, startCol: startCol, direction: direction)
            }
        }
        
        return nil
    }
    
    /// Check if a word can be placed at a position
    private func canPlace(_ word: String, at row: Int, col: Int, direction: WordDirection, in grid: [[GridCell]]) -> Bool {
        for (i, char) in word.enumerated() {
            let newRow = row + (direction.rowDelta * i)
            let newCol = col + (direction.colDelta * i)
            
            // Check bounds
            guard newRow >= 0, newRow < gridSize, newCol >= 0, newCol < gridSize else {
                return false
            }
            
            // Check if cell is empty or has the same letter
            let existingLetter = grid[newRow][newCol].letter
            if existingLetter != " " && existingLetter != char {
                return false
            }
        }
        
        return true
    }
    
    /// Handle cell selection during drag
    func selectCell(at row: Int, col: Int) {
        guard row >= 0, row < gridSize, col >= 0, col < gridSize else { return }
        
        let cell = grid[row][col]
        
        // Check if this cell is already selected in current drag
        if selectedCells.contains(where: { $0.row == row && $0.col == col }) {
            return
        }
        
        // Validate selection is in a straight line
        if !selectedCells.isEmpty {
            guard isValidSelection(row: row, col: col) else { return }
        }
        
        selectedCells.append(cell)
        updateGridSelection()
    }
    
    /// Check if adding this cell maintains a straight line
    private func isValidSelection(row: Int, col: Int) -> Bool {
        guard let first = selectedCells.first else { return true }
        
        if selectedCells.count == 1 {
            // Any adjacent cell is valid for second selection
            let rowDiff = abs(row - first.row)
            let colDiff = abs(col - first.col)
            return rowDiff <= 1 && colDiff <= 1 && (rowDiff > 0 || colDiff > 0)
        }
        
        // Must continue in same direction
        let second = selectedCells[1]
        let rowDir = second.row - first.row
        let colDir = second.col - first.col
        
        guard let last = selectedCells.last else { return false }
        let expectedRow = last.row + rowDir
        let expectedCol = last.col + colDir
        
        return row == expectedRow && col == expectedCol
    }
    
    /// Update grid to show current selection
    private func updateGridSelection() {
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let isSelected = selectedCells.contains { $0.row == row && $0.col == col }
                // Allow selection state to update even on found cells (for overlapping words)
                if grid[row][col].isSelected != isSelected {
                    grid[row][col].isSelected = isSelected
                }
            }
        }
    }
    
    /// Complete selection and check for word match
    func endSelection() {
        let selectedWord = String(selectedCells.map { $0.letter })
        let reversedWord = String(selectedWord.reversed())
        
        // Check if selection matches any placed word
        for i in 0..<placedWords.count {
            let placedWord = placedWords[i]
            if !placedWord.isFound {
                let cleanedWord = placedWord.word.cleanedWord
                if selectedWord == cleanedWord || reversedWord == cleanedWord {
                    // Found a word!
                    markWordAsFound(at: i)
                    foundWord = placedWord.word
                    showDefinition = true
                    break
                }
            }
        }
        
        // Clear selection
        clearSelection()
    }
    
    /// Mark a word as found
    private func markWordAsFound(at index: Int) {
        placedWords[index].isFound = true
        wordsFound += 1
        
        // Mark cells as found
        let word = placedWords[index]
        for (row, col) in word.cells {
            grid[row][col].isFound = true
            grid[row][col].foundWordId = word.id
        }
        
        // Check if game is complete
        if wordsFound == placedWords.count {
            isGameComplete = true
        }
    }
    
    /// Clear current selection
    func clearSelection() {
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                // Clear selection on all cells (including found ones that may have been re-selected)
                grid[row][col].isSelected = false
            }
        }
        selectedCells = []
    }
    
    /// Dismiss the definition popup
    func dismissDefinition() {
        showDefinition = false
        foundWord = nil
    }
    
    /// Get color for a found word
    func colorForFoundWord(_ wordId: UUID?) -> Color {
        guard let wordId = wordId,
              let index = placedWords.firstIndex(where: { $0.id == wordId }) else {
            return .clear
        }
        
        let colors: [Color] = [
            .green.opacity(0.4),
            .blue.opacity(0.4),
            .purple.opacity(0.4),
            .orange.opacity(0.4),
            .pink.opacity(0.4),
            .cyan.opacity(0.4),
            .yellow.opacity(0.4),
            .mint.opacity(0.4)
        ]
        
        return colors[index % colors.count]
    }
}
