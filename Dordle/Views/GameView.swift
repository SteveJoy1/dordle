import SwiftUI

struct GameView: View {
    @State private var engine = GameEngine()

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.width < 420

            VStack(spacing: 0) {
                // Header
                header
                    .padding(.horizontal)
                    .padding(.vertical, 10)

                Divider()

                // Toast
                ZStack {
                    if let msg = engine.message {
                        Text(msg)
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(.label).opacity(0.88))
                            .clipShape(Capsule())
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .frame(height: 36)
                .animation(.easeInOut(duration: 0.25), value: engine.message != nil)

                Spacer(minLength: 2)

                // Two boards
                HStack(alignment: .top, spacing: compact ? 6 : 12) {
                    BoardView(
                        targetWord: engine.targetWords.0,
                        guesses: engine.guesses,
                        currentGuess: engine.currentGuess,
                        maxGuesses: engine.maxGuesses,
                        isSolved: engine.board1Solved,
                        isGameOver: engine.gameOver,
                        shakeCurrentRow: engine.shakeRow,
                        label: "1"
                    )
                    BoardView(
                        targetWord: engine.targetWords.1,
                        guesses: engine.guesses,
                        currentGuess: engine.currentGuess,
                        maxGuesses: engine.maxGuesses,
                        isSolved: engine.board2Solved,
                        isGameOver: engine.gameOver,
                        shakeCurrentRow: engine.shakeRow,
                        label: "2"
                    )
                }
                .padding(.horizontal, 8)

                Spacer(minLength: 4)

                // Game-over actions
                if engine.gameOver {
                    VStack(spacing: 10) {
                        // Stats pill
                        HStack(spacing: 16) {
                            stat(label: "Played", value: "\(engine.totalPlayed)")
                            stat(label: "Won", value: "\(engine.totalWins)")
                            stat(
                                label: "Win %",
                                value: engine.totalPlayed > 0
                                    ? "\(engine.totalWins * 100 / engine.totalPlayed)%"
                                    : "–"
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .clipShape(Capsule())

                        HStack(spacing: 12) {
                            Button {
                                withAnimation { engine.retryCurrent() }
                            } label: {
                                Label("Retry", systemImage: "arrow.uturn.backward")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(Color.accentColor)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.accentColor, lineWidth: 2)
                                    )
                            }

                            Button {
                                withAnimation { engine.nextPair() }
                            } label: {
                                Label("Next Pair", systemImage: "arrow.right")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.accentColor)
                                    )
                            }
                        }
                    }
                    .padding(.vertical, 6)
                    .transition(.scale.combined(with: .opacity))
                }

                Spacer(minLength: 4)

                // Keyboard
                KeyboardView(
                    states1: engine.keyboardStates(for: 0),
                    states2: engine.keyboardStates(for: 1),
                    onKey: handleKey
                )
                .padding(.horizontal, 4)
                .padding(.bottom, 6)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("DORDLE")
                .font(.title2.bold())
                .kerning(3)

            Spacer()

            // Pair progress
            Text("Pair \(engine.pairIndex + 1)/\(engine.totalPairs)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            if !engine.gameOver {
                Text("·")
                    .foregroundStyle(.secondary)
                Text("\(engine.guesses.count)/\(engine.maxGuesses)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Button {
                withAnimation { engine.retryCurrent() }
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.body)
            }
        }
    }

    // MARK: - Helpers

    private func stat(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.bold())
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func handleKey(_ key: String) {
        switch key {
        case "ENTER": engine.submitGuess()
        case "DEL":   engine.removeLetter()
        default:
            if let ch = key.first, key.count == 1 {
                engine.addLetter(ch)
            }
        }
    }
}

#Preview {
    GameView()
}
