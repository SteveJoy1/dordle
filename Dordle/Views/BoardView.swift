import SwiftUI

struct BoardView: View {
    let targetWord: String
    let guesses: [String]
    let currentGuess: String
    let maxGuesses: Int
    let isSolved: Bool
    let isGameOver: Bool
    let shakeCurrentRow: Bool
    let label: String
    var revealDelays: [Double]? = nil
    var currentGuessInvalid: Bool = false

    @State private var revealedRows: Set<Int> = []
    @State private var revealingRow: Int? = nil

    private let flipDuration = 0.2 // total per tile

    var body: some View {
        VStack(spacing: 3) {
            ForEach(0..<maxGuesses, id: \.self) { row in
                rowView(row)
            }

            if isSolved {
                Text("Solved!")
                    .font(.caption2.bold())
                    .foregroundStyle(.green)
                    .padding(.top, 2)
            }
        }
        .onAppear {
            revealedRows = Set(0..<guesses.count)
        }
        .onChange(of: revealDelays) { _, newDelays in
            if let delays = newDelays, guesses.count > 0 {
                let newRow = guesses.count - 1
                guard !revealedRows.contains(newRow) else { return }
                revealingRow = newRow
                let maxDelay = delays.max() ?? 0
                DispatchQueue.main.asyncAfter(deadline: .now() + maxDelay + flipDuration + 0.05) {
                    revealedRows.insert(newRow)
                    revealingRow = nil
                }
            }
        }
        .onChange(of: guesses.count) { old, new in
            if new < old {
                revealedRows.removeAll()
                revealingRow = nil
            }
        }
    }

    @ViewBuilder
    private func rowView(_ row: Int) -> some View {
        let isCurrentRow = row == guesses.count && !isGameOver

        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { col in
                tile(row: row, col: col)
            }
        }
        .offset(x: isCurrentRow && shakeCurrentRow ? shakeOffset : 0)
        .animation(
            isCurrentRow && shakeCurrentRow
                ? .linear(duration: 0.06).repeatCount(5, autoreverses: true)
                : .default,
            value: shakeCurrentRow
        )
    }

    @ViewBuilder
    private func tile(row: Int, col: Int) -> some View {
        if row < guesses.count {
            let guess = guesses[row]
            let chars = Array(guess)
            let eval = GameEngine.evaluate(guess: guess, target: targetWord)
            let isRevealed = revealedRows.contains(row)
            let isActiveReveal = revealingRow == row

            if isRevealed {
                // Already revealed — show final colors, no animation
                TileView(letter: chars[col], status: eval[col])
            } else if isActiveReveal, let delays = revealDelays {
                // Currently flipping
                TileView(
                    letter: chars[col],
                    status: eval[col],
                    isRevealing: true,
                    revealDelay: delays[col]
                )
            } else {
                // Pending reveal — show letter but no color yet
                TileView(letter: chars[col], status: .typed)
            }
        } else if row == guesses.count && !isGameOver {
            let chars = Array(currentGuess)
            let letter: Character? = col < chars.count ? chars[col] : nil
            TileView(
                letter: letter,
                status: letter != nil ? .typed : .empty,
                isInvalid: currentGuessInvalid && currentGuess.count == 5
            )
        } else {
            TileView(letter: nil, status: .empty)
        }
    }

    private var shakeOffset: CGFloat { 8 }
}
