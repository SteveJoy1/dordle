import SwiftUI

struct GameView: View {
    @State private var engine = GameEngine()
    @State private var showResetAlert = false
    @State private var showHistory = false
    @State private var board1Delays: [Double]? = nil
    @State private var board2Delays: [Double]? = nil

    private let flipDuration = 0.4

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
                        label: "1",
                        revealDelays: board1Delays,
                        currentGuessInvalid: engine.currentGuessInvalid
                    )
                    BoardView(
                        targetWord: engine.targetWords.1,
                        guesses: engine.guesses,
                        currentGuess: engine.currentGuess,
                        maxGuesses: engine.maxGuesses,
                        isSolved: engine.board2Solved,
                        isGameOver: engine.gameOver,
                        shakeCurrentRow: engine.shakeRow,
                        label: "2",
                        revealDelays: board2Delays,
                        currentGuessInvalid: engine.currentGuessInvalid
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
                    splitRatio: keyboardSplitRatio,
                    onKey: handleKey
                )
                .padding(.horizontal, 4)
                .padding(.bottom, 6)
            }
        }
        .onChange(of: engine.guesses.count) { old, new in
            if new > old {
                // 10 tiles across both boards, random sequential order
                var order = Array(0..<10)
                order.shuffle()
                var d1 = [Double](repeating: 0, count: 5)
                var d2 = [Double](repeating: 0, count: 5)
                for (position, tile) in order.enumerated() {
                    let delay = Double(position) * flipDuration
                    if tile < 5 {
                        d1[tile] = delay
                    } else {
                        d2[tile - 5] = delay
                    }
                }
                board1Delays = d1
                board2Delays = d2
                let total = Double(9) * flipDuration + flipDuration + 0.1
                DispatchQueue.main.asyncAfter(deadline: .now() + total) {
                    board1Delays = nil
                    board2Delays = nil
                }
            } else if new < old {
                board1Delays = nil
                board2Delays = nil
            }
        }
        .alert("Reset this game?", isPresented: $showResetAlert) {
            Button("Reset", role: .destructive) {
                withAnimation { engine.retryCurrent() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All guesses for this pair will be cleared.")
        }
        .sheet(isPresented: $showHistory) {
            HistoryView(engine: engine)
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

            // History button
            Button { showHistory = true } label: {
                Image(systemName: "chart.bar")
                    .font(.body)
            }

            // Reset button (with confirmation when there are guesses)
            Button {
                if engine.guesses.isEmpty {
                    withAnimation { engine.retryCurrent() }
                } else {
                    showResetAlert = true
                }
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.body)
            }
        }
    }

    // MARK: - Helpers

    private var keyboardSplitRatio: CGFloat {
        if engine.board1Solved && !engine.board2Solved { return 0.25 }
        if engine.board2Solved && !engine.board1Solved { return 0.75 }
        return 0.5
    }

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
