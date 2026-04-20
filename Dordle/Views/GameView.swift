import SwiftUI

struct GameView: View {
    @State private var engine = GameEngine()
    @State private var showResetAlert = false
    @State private var showHistory = false
    @State private var board1Delays: [Double]? = nil
    @State private var board2Delays: [Double]? = nil
    @State private var animating = false
    @State private var pendingMessage: String? = nil
    @Environment(\.scenePhase) private var scenePhase

    private let flipDuration = 0.28

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.width < 420

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

                        // One pair per day — show when next pair unlocks
                        Text(nextPairMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.vertical, 6)
                    .transition(.scale.combined(with: .opacity))
                }

                Spacer(minLength: 4)

                // Keyboard — freezes state during flip animation
                KeyboardView(
                    states1: engine.keyboardStates(for: 0, upTo: effectiveGuessCount),
                    states2: engine.keyboardStates(for: 1, upTo: effectiveGuessCount),
                    splitRatio: keyboardSplitRatio,
                    onKey: handleKey
                )
                .padding(.horizontal, 4)
                .padding(.bottom, 6)
            }
        }
        .onChange(of: engine.guesses.count) { old, new in
            if new > old {
                let lastIdx = new - 1
                // A board was "already solved" if it solved on a prior row
                let b1WasSolved = engine.board1Solved &&
                    engine.guesses.firstIndex(of: engine.targetWords.0) != lastIdx
                let b2WasSolved = engine.board2Solved &&
                    engine.guesses.firstIndex(of: engine.targetWords.1) != lastIdx

                // Only include tiles from boards that still need revealing
                var pool = [Int]()
                if !b1WasSolved { pool.append(contentsOf: 0..<5) }
                if !b2WasSolved { pool.append(contentsOf: 5..<10) }
                pool.shuffle()

                var d1 = [Double](repeating: 0, count: 5)
                var d2 = [Double](repeating: 0, count: 5)
                for (position, tile) in pool.enumerated() {
                    let delay = Double(position) * flipDuration
                    if tile < 5 {
                        d1[tile] = delay
                    } else {
                        d2[tile - 5] = delay
                    }
                }
                board1Delays = b1WasSolved ? nil : d1
                board2Delays = b2WasSolved ? nil : d2
                animating = true
                pendingMessage = engine.message
                let total = Double(max(pool.count - 1, 0)) * flipDuration + flipDuration + 0.1
                DispatchQueue.main.asyncAfter(deadline: .now() + total) {
                    board1Delays = nil
                    board2Delays = nil
                    animating = false
                    // Auto-clear deferred message after 2.5s
                    if pendingMessage != nil {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            pendingMessage = nil
                        }
                    }
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
        .onChange(of: scenePhase) { _, newPhase in
            // If the app resumes on a new day, roll over to today's pair.
            if newPhase == .active {
                engine.refreshForToday()
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

            // Daily Dordle number (matches zaratustra.itch.io/dordle)
            Text("#\(String(format: "%04d", engine.pairIndex))")
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

    private var keyboardSplitRatio: CGFloat {
        guard !animating else { return 0.5 }
        if engine.board1Solved && !engine.board2Solved { return 0.25 }
        if engine.board2Solved && !engine.board1Solved { return 0.75 }
        return 0.5
    }

    /// Human-readable message about when the next pair unlocks.
    private var nextPairMessage: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let cal = Calendar.current
        guard let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date())) else {
            return "Come back tomorrow for a new pair!"
        }
        return "Next pair \(formatter.localizedString(for: tomorrow, relativeTo: Date()))"
    }

    /// Number of guesses the keyboard should reflect — excludes the currently
    /// animating guess so keys don't change color until the flip completes.
    private var effectiveGuessCount: Int {
        animating ? max(engine.guesses.count - 1, 0) : engine.guesses.count
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

    /// True if pressing ENTER right now will produce a flip animation
    /// (current guess is a complete, valid word).
    private var willSubmitAnimate: Bool {
        engine.currentGuess.count == 5
            && WordList.isValid(engine.currentGuess.uppercased())
            && !engine.gameOver
    }
}

#Preview {
    GameView()
}
