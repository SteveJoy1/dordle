import SwiftUI

struct WordleGameView: View {
    @State private var engine = WordleGameEngine()
    @State private var showResetAlert = false
    @State private var showHistory = false
    @State private var revealDelays: [Double]? = nil
    @State private var animating = false
    @State private var pendingMessage: String? = nil
    @Environment(\.scenePhase) private var scenePhase

    private let flipDuration = 0.28

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

                        // One word per day — show when next word unlocks
                        Text(nextWordMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.vertical, 6)
                    .transition(.scale.combined(with: .opacity))
                }

                Spacer(minLength: 4)

                // Keyboard — single-board mode, freezes during flip animation
                KeyboardView(
                    states1: engine.keyboardStates(upTo: effectiveGuessCount),
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
        .onChange(of: scenePhase) { _, newPhase in
            // If the app is resumed on a new day, roll over to today's word.
            if newPhase == .active {
                engine.refreshForToday()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("WORDLE")
                .font(.title2.bold())
                .kerning(3)

            Spacer()

            // Daily word number
            Text("#\(engine.wordIndex + 1)")
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

    /// Number of guesses the keyboard should reflect — excludes the currently
    /// animating guess so keys don't change color until the flip completes.
    private var effectiveGuessCount: Int {
        animating ? max(engine.guesses.count - 1, 0) : engine.guesses.count
    }

    /// Human-readable message about when the next word unlocks.
    private var nextWordMessage: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let cal = Calendar.current
        guard let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date())) else {
            return "Come back tomorrow for a new word!"
        }
        let delta = formatter.localizedString(for: tomorrow, relativeTo: Date())
        return "Next word \(delta)"
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
        case "ENTER":
            // Pre-emptively enter animating state for valid guesses so the
            // engine's success message is hidden from the moment it's set,
            // avoiding a 1-frame flash before .onChange fires.
            if willSubmitAnimate { animating = true }
            engine.submitGuess()
        case "DEL":   engine.removeLetter()
        default:
            if let ch = key.first, key.count == 1 {
                engine.addLetter(ch)
            }
        }
    }

    /// True if pressing ENTER right now will produce a flip animation.
    private var willSubmitAnimate: Bool {
        engine.currentGuess.count == 5
            && WordList.isValid(engine.currentGuess.uppercased())
            && !engine.gameOver
    }
}

#Preview {
    WordleGameView()
}
