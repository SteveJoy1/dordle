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

    @State private var revealedRows: Set<Int> = []
    @State private var revealingRow: Int? = nil

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
            // Seed already-submitted rows as revealed (no animation on restore)
            revealedRows = Set(0..<guesses.count)
        }
        .onChange(of: guesses.count) { old, new in
            if new > old {
                // A new guess was just submitted — animate the new row
                let newRow = new - 1
                revealingRow = newRow
                // After the staggered flip finishes (~0.15s * 4 cols + 0.7s flip)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                    revealedRows.insert(newRow)
                    revealingRow = nil
                }
            } else if new < old {
                // Game was reset
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
            let isActiveReveal = revealingRow == row && !revealedRows.contains(row)
            TileView(
                letter: chars[col],
                status: eval[col],
                isRevealing: isActiveReveal,
                revealDelay: isActiveReveal ? Double(col) * 0.15 : 0
            )
        } else if row == guesses.count && !isGameOver {
            let chars = Array(currentGuess)
            let letter: Character? = col < chars.count ? chars[col] : nil
            TileView(letter: letter, status: letter != nil ? .typed : .empty)
        } else {
            TileView(letter: nil, status: .empty)
        }
    }

    private var shakeOffset: CGFloat { 8 }
}
