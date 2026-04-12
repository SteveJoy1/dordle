import SwiftUI

struct WordleGameView: View {
    @State private var engine = WordleGameEngine()
    @State private var showResetAlert = false
    @State private var showHistory = false
    @State private var revealDelays: [Double]? = nil
    @State private var animating = false
    @State private var pendingMessage: String? = nil

    private let flipDuration = 0.4

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // Header
                header
                    .padding(.horizontal)
                    .padding(.vertical, 10)

                Divider()

                // Toast — deferred until flip animations complete
                ZStack {
                    if let msg = animating ? nil : (pendingMessage ?? engine.message) {
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
                .animation(.easeInOut(duration: 0.25), value: animating ? nil : (pendingMessage ?? engine.message))

                Spacer(minLength: 2)

                // Single board, centered, max 320pt wide
                BoardView(
                    targetWord: engine.targetWord,
                    guesses: engine.guesses,
                    currentGuess: engine.currentGuess,
                    maxGuesses: engine.maxGuesses,
                    isSolved: engine.won,
                    isGameOver: engine.gameOver,
                    shakeCurrentRow: engine.shakeRow,
                    label: "",
                    revealDelays: revealDelays,
                    currentGuessInvalid: engine.currentGuessInvalid
                )
                .frame(maxWidth: 260)
                .padding(.horizontal, 24)

                Spacer(minLength: 4)

                // Game-over actions — wait for flip animations
                if engine.gameOver && !animating {
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
                                withAnimation { engine.nextWord() }
                            } label: {
                                Label("New Word", systemImage: "arrow.right")
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

                // Keyboard — single-board mode
                KeyboardView(
                    states1: engine.keyboardStates(),
                    states2: [:],
                    splitRatio: 1.0,
                    onKey: handleKey
                )
                .padding(.horizontal, 4)
                .padding(.bottom, 6)
            }
        }
        .onChange(of: engine.guesses.count) { old, new in
            if new > old {
                var order = Array(0..<5)
                order.shuffle()
                var delays = [Double](repeating: 0, count: 5)
                for (position, tile) in order.enumerated() {
                    delays[tile] = Double(position) * flipDuration
                }
                revealDelays = delays
                animating = true
                pendingMessage = engine.message
                let total = Double(4) * flipDuration + flipDuration + 0.1
                DispatchQueue.main.asyncAfter(deadline: .now() + total) {
                    revealDelays = nil
                    animating = false
                    if pendingMessage != nil {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            pendingMessage = nil
                        }
                    }
                }
            } else if new < old {
                revealDelays = nil
            }
        }
        .alert("Reset this game?", isPresented: $showResetAlert) {
            Button("Reset", role: .destructive) {
                withAnimation { engine.retryCurrent() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All guesses for this word will be cleared.")
        }
        .sheet(isPresented: $showHistory) {
            WordleHistoryView(engine: engine)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("WORDLE")
                .font(.title2.bold())
                .kerning(3)

            Spacer()

            // Word progress
            Text("Word \(engine.wordIndex + 1)/\(engine.totalWords)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            if !engine.gameOver || animating {
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
    WordleGameView()
}
