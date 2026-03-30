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
            TileView(letter: chars[col], status: eval[col])
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
