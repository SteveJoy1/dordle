import SwiftUI

// MARK: - Wordle Record (persisted history)

struct WordleRecord: Codable, Identifiable {
    let id: UUID
    let wordIndex: Int
    let word: String
    let guesses: [String]
    let won: Bool
    let date: Date
    let guessCount: Int

    init(wordIndex: Int, word: String, guesses: [String], won: Bool) {
        self.id = UUID()
        self.wordIndex = wordIndex
        self.word = word
        self.guesses = guesses
        self.won = won
        self.date = Date()
        self.guessCount = guesses.count
    }
}

// MARK: - Wordle Game Engine

@Observable
final class WordleGameEngine {
    let maxGuesses = 6
    let wordLength = 5

    private(set) var targetWord: String = ""
    private(set) var guesses: [String] = []
    private(set) var currentGuess: String = ""
    private(set) var gameOver: Bool = false
    private(set) var won: Bool = false
    private(set) var message: String?
    private(set) var shakeRow: Bool = false

    /// Current word index — persisted.
    var wordIndex: Int {
        get { UserDefaults.standard.integer(forKey: "wordle_wordIndex") }
        set { UserDefaults.standard.set(newValue, forKey: "wordle_wordIndex") }
    }

    /// Lifetime wins — persisted.
    var totalWins: Int {
        get { UserDefaults.standard.integer(forKey: "wordle_totalWins") }
        set { UserDefaults.standard.set(newValue, forKey: "wordle_totalWins") }
    }

    /// Lifetime games played — persisted.
    var totalPlayed: Int {
        get { UserDefaults.standard.integer(forKey: "wordle_totalPlayed") }
        set { UserDefaults.standard.set(newValue, forKey: "wordle_totalPlayed") }
    }

    var solved: Bool { guesses.contains(targetWord) }
    var totalWords: Int { WordList.totalWords }

    /// Game history — persisted as JSON in UserDefaults.
    var history: [WordleRecord] {
        get {
            guard let data = UserDefaults.standard.data(forKey: "wordle_gameHistory"),
                  let records = try? JSONDecoder().decode([WordleRecord].self, from: data)
            else { return [] }
            return records
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "wordle_gameHistory")
            }
        }
    }

    init() {
        loadCurrentWord()
    }

    // MARK: - Game lifecycle

    func loadCurrentWord() {
        targetWord = WordList.word(at: wordIndex)
        gameOver = false
        won = false
        message = nil

        // Restore in-progress state if it matches the current word
        let savedIndex = UserDefaults.standard.integer(forKey: "wordle_inProgressWordIndex")
        if savedIndex == wordIndex,
           let savedGuesses = UserDefaults.standard.stringArray(forKey: "wordle_inProgressGuesses") {
            guesses = savedGuesses
            currentGuess = UserDefaults.standard.string(forKey: "wordle_inProgressCurrent") ?? ""

            if guesses.contains(targetWord) {
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

    func nextWord() {
        wordIndex += 1
        clearInProgressState()
        loadCurrentWord()
    }

    func retryCurrent() {
        clearInProgressState()
        loadCurrentWord()
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

        guesses.append(word)
        currentGuess = ""

        if word == targetWord {
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
            flash("The word was \(targetWord)", duration: 5)
        }

        saveInProgressState()
    }

    // MARK: - Keyboard state

    func keyboardStates() -> [Character: TileStatus] {
        let rank: [TileStatus: Int] = [.absent: 1, .present: 2, .correct: 3]
        var map: [Character: TileStatus] = [:]

        for guess in guesses {
            let statuses = GameEngine.evaluate(guess: guess, target: targetWord)
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
        UserDefaults.standard.set(wordIndex, forKey: "wordle_inProgressWordIndex")
        UserDefaults.standard.set(guesses, forKey: "wordle_inProgressGuesses")
        UserDefaults.standard.set(currentGuess, forKey: "wordle_inProgressCurrent")
    }

    private func clearInProgressState() {
        UserDefaults.standard.removeObject(forKey: "wordle_inProgressGuesses")
        UserDefaults.standard.removeObject(forKey: "wordle_inProgressCurrent")
    }

    private func recordGame() {
        let record = WordleRecord(
            wordIndex: wordIndex,
            word: targetWord,
            guesses: guesses,
            won: won
        )
        var h = history
        h.insert(record, at: 0)
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
