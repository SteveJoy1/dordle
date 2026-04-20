import SwiftUI

enum TileStatus: Equatable {
    case empty
    case typed
    case correct
    case present
    case absent
}

// MARK: - Game Record (persisted history)

struct GameRecord: Codable, Identifiable {
    let id: UUID
    let pairIndex: Int
    let word1: String
    let word2: String
    let guesses: [String]
    let won: Bool
    let date: Date
    let guessCount: Int

    init(pairIndex: Int, word1: String, word2: String, guesses: [String], won: Bool) {
        self.id = UUID()
        self.pairIndex = pairIndex
        self.word1 = word1
        self.word2 = word2
        self.guesses = guesses
        self.won = won
        self.date = Date()
        self.guessCount = guesses.count
    }
}

// MARK: - Game Engine

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

    /// Today's Dordle seed = days since Dordle's launch date (2022-01-24).
    /// Not mutable — you get one pair per calendar day, missed days are gone.
    var pairIndex: Int { WordList.dordleSeed() }

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

    var currentGuessInvalid: Bool {
        currentGuess.count == wordLength && !WordList.isValid(currentGuess.uppercased())
    }

    var board1Solved: Bool { guesses.contains(targetWords.0) }
    var board2Solved: Bool { guesses.contains(targetWords.1) }

    /// Game history — persisted as JSON in UserDefaults.
    var history: [GameRecord] {
        get {
            guard let data = UserDefaults.standard.data(forKey: "gameHistory"),
                  let records = try? JSONDecoder().decode([GameRecord].self, from: data)
            else { return [] }
            return records
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "gameHistory")
            }
        }
    }

    init() {
        loadCurrentPair()
    }

    // MARK: - Game lifecycle

    /// Load today's pair (date-seeded), restoring in-progress guesses if any.
    func loadCurrentPair() {
        let pair = WordList.dordlePair(seed: pairIndex)
        targetWords = pair
        gameOver = false
        won = false
        message = nil

        // Restore in-progress state if it matches today's pair
        let savedPair = UserDefaults.standard.integer(forKey: "inProgressPairIndex")
        if savedPair == pairIndex,
           let savedGuesses = UserDefaults.standard.stringArray(forKey: "inProgressGuesses") {
            guesses = savedGuesses
            currentGuess = UserDefaults.standard.string(forKey: "inProgressCurrent") ?? ""

            let now1 = guesses.contains(targetWords.0)
            let now2 = guesses.contains(targetWords.1)
            if now1 && now2 {
                won = true
                gameOver = true
            } else if guesses.count >= maxGuesses {
                gameOver = true
            }
        } else {
            guesses = []
            currentGuess = ""
            saveInProgressState()
        }
    }

    /// Reload today's pair (e.g. if the day rolled over while app was open).
    func refreshForToday() {
        loadCurrentPair()
    }

    /// Restart today's pair from scratch.
    func retryCurrent() {
        clearInProgressState()
        loadCurrentPair()
    }

    // MARK: - Input

    func addLetter(_ ch: Character) {
        guard !gameOver, currentGuess.count < wordLength else { return }
        currentGuess.append(ch)
        saveInProgressState()
    }

    func removeLetter() {
        guard !gameOver, !currentGuess.isEmpty else { return }
        currentGuess.removeLast()
        saveInProgressState()
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
            recordGame()
            flash("Brilliant!")
        } else if guesses.count >= maxGuesses {
            gameOver = true
            totalPlayed += 1
            recordGame()
            var parts: [String] = []
            if !now1 { parts.append(targetWords.0) }
            if !now2 { parts.append(targetWords.1) }
            flash("Game over! \(parts.joined(separator: ", "))", duration: 5)
        } else if now1 && !was1 {
            flash("Left board solved!")
        } else if now2 && !was2 {
            flash("Right board solved!")
        }

        saveInProgressState()
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

    func keyboardStates(for board: Int, upTo count: Int? = nil) -> [Character: TileStatus] {
        let target = board == 0 ? targetWords.0 : targetWords.1
        let rank: [TileStatus: Int] = [.absent: 1, .present: 2, .correct: 3]
        var map: [Character: TileStatus] = [:]

        let limit = min(count ?? guesses.count, guesses.count)
        for guess in guesses.prefix(limit) {
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

    // MARK: - Persistence helpers

    private func saveInProgressState() {
        UserDefaults.standard.set(pairIndex, forKey: "inProgressPairIndex")
        UserDefaults.standard.set(guesses, forKey: "inProgressGuesses")
        UserDefaults.standard.set(currentGuess, forKey: "inProgressCurrent")
    }

    private func clearInProgressState() {
        UserDefaults.standard.removeObject(forKey: "inProgressGuesses")
        UserDefaults.standard.removeObject(forKey: "inProgressCurrent")
    }

    private func recordGame() {
        let record = GameRecord(
            pairIndex: pairIndex,
            word1: targetWords.0,
            word2: targetWords.1,
            guesses: guesses,
            won: won
        )
        var h = history
        h.insert(record, at: 0) // newest first
        // Keep last 200 games max
        if h.count > 200 { h = Array(h.prefix(200)) }
        history = h
        clearInProgressState()
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
