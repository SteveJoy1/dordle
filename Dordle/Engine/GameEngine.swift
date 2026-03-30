import SwiftUI

enum TileStatus: Equatable {
    case empty
    case typed
    case correct
    case present
    case absent
}

@Observable
final class GameEngine {
    let maxGuesses = 7
    let wordLength = 5

    private(set) var targetWords: (String, String) = ("", "")
    private(set) var guesses: [String] = []
    private(set) var currentGuess: String = ""
    private(set) var gameOver: Bool = false
    private(set) var won: Bool = false
    private(set) var message: String?
    private(set) var shakeRow: Bool = false

    /// Current pair index — persisted across launches.
    var pairIndex: Int {
        get { UserDefaults.standard.integer(forKey: "pairIndex") }
        set { UserDefaults.standard.set(newValue, forKey: "pairIndex") }
    }

    /// Lifetime wins — persisted.
    var totalWins: Int {
        get { UserDefaults.standard.integer(forKey: "totalWins") }
        set { UserDefaults.standard.set(newValue, forKey: "totalWins") }
    }

    /// Lifetime games played — persisted.
    var totalPlayed: Int {
        get { UserDefaults.standard.integer(forKey: "totalPlayed") }
        set { UserDefaults.standard.set(newValue, forKey: "totalPlayed") }
    }

    var board1Solved: Bool { guesses.contains(targetWords.0) }
    var board2Solved: Bool { guesses.contains(targetWords.1) }
    var totalPairs: Int { WordList.totalPairs }

    init() {
        loadCurrentPair()
    }

    // MARK: - Game lifecycle

    /// Load the pair at the current persisted index.
    func loadCurrentPair() {
        let pair = WordList.pair(at: pairIndex)
        targetWords = pair
        guesses = []
        currentGuess = ""
        gameOver = false
        won = false
        message = nil
    }

    /// Advance to the next pair and start a new game.
    func nextPair() {
        pairIndex += 1
        loadCurrentPair()
    }

    /// Restart the current pair from scratch.
    func retryCurrent() {
        loadCurrentPair()
    }

    // MARK: - Input

    func addLetter(_ ch: Character) {
        guard !gameOver, currentGuess.count < wordLength else { return }
        currentGuess.append(ch)
    }

    func removeLetter() {
        guard !gameOver, !currentGuess.isEmpty else { return }
        currentGuess.removeLast()
    }

    func submitGuess() {
        guard !gameOver else { return }

        guard currentGuess.count == wordLength else {
            flash("Not enough letters")
            triggerShake()
            return
        }

        let word = currentGuess.uppercased()
        guard WordList.isValid(word) else {
            flash("Not in word list")
            triggerShake()
            return
        }

        let was1 = board1Solved
        let was2 = board2Solved

        guesses.append(word)
        currentGuess = ""

        let now1 = board1Solved
        let now2 = board2Solved

        if now1 && now2 {
            won = true
            gameOver = true
            totalWins += 1
            totalPlayed += 1
            flash("Brilliant!")
        } else if guesses.count >= maxGuesses {
            gameOver = true
            totalPlayed += 1
            var parts: [String] = []
            if !now1 { parts.append(targetWords.0) }
            if !now2 { parts.append(targetWords.1) }
            flash("Game over! \(parts.joined(separator: ", "))", duration: 5)
        } else if now1 && !was1 {
            flash("Left board solved!")
        } else if now2 && !was2 {
            flash("Right board solved!")
        }
    }

    // MARK: - Evaluation

    static func evaluate(guess: String, target: String) -> [TileStatus] {
        let g = Array(guess)
        var t = Array(target)
        var result: [TileStatus] = Array(repeating: .absent, count: 5)

        for i in 0..<5 where g[i] == t[i] {
            result[i] = .correct
            t[i] = "\0"
        }

        for i in 0..<5 where result[i] != .correct {
            if let j = t.firstIndex(of: g[i]) {
                result[i] = .present
                t[j] = "\0"
            }
        }

        return result
    }

    func keyboardStates(for board: Int) -> [Character: TileStatus] {
        let target = board == 0 ? targetWords.0 : targetWords.1
        let rank: [TileStatus: Int] = [.absent: 1, .present: 2, .correct: 3]
        var map: [Character: TileStatus] = [:]

        for guess in guesses {
            let statuses = Self.evaluate(guess: guess, target: target)
            for (i, ch) in guess.enumerated() {
                let s = statuses[i]
                if (rank[s] ?? 0) > (rank[map[ch] ?? .empty] ?? 0) {
                    map[ch] = s
                }
            }
        }
        return map
    }

    // MARK: - Helpers

    private func flash(_ msg: String, duration: TimeInterval = 2.5) {
        message = msg
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            if message == msg { message = nil }
        }
    }

    private func triggerShake() {
        shakeRow = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.5))
            shakeRow = false
        }
    }
}
