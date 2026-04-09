import SwiftUI

struct WordleHistoryView: View {
    let engine: WordleGameEngine
    @Environment(\.dismiss) private var dismiss

    private var records: [WordleRecord] { engine.history }

    private var winRate: Int {
        guard engine.totalPlayed > 0 else { return 0 }
        return engine.totalWins * 100 / engine.totalPlayed
    }

    var body: some View {
        NavigationStack {
            List {
                // Summary section
                Section {
                    HStack(spacing: 0) {
                        statBlock(value: "\(engine.totalPlayed)", label: "Played")
                        statBlock(value: "\(engine.totalWins)", label: "Won")
                        statBlock(value: "\(winRate)%", label: "Win Rate")
                        statBlock(value: "\(engine.wordIndex + 1)", label: "Current Word")
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                }

                // Game log
                Section("Game History") {
                    if records.isEmpty {
                        Text("No completed games yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(records) { record in
                            gameRow(record)
                        }
                    }
                }
            }
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Subviews

    private func statBlock(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func gameRow(_ record: WordleRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                // Result badge
                Image(systemName: record.won ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(record.won ? .green : .red)

                Text("Word \(record.wordIndex + 1)")
                    .font(.subheadline.bold())

                Spacer()

                Text(record.date, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Word
            wordPill(record.word)

            // Guess summary
            Text("\(record.guessCount)/6 guesses")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Mini guess grid
            miniGrid(record: record)
        }
        .padding(.vertical, 4)
    }

    private func wordPill(_ word: String) -> some View {
        Text(word)
            .font(.caption.bold().monospaced())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color(.systemGray5))
            .clipShape(Capsule())
    }

    private func miniGrid(record: WordleRecord) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(record.guesses.indices, id: \.self) { i in
                miniRow(guess: record.guesses[i], target: record.word)
            }
        }
    }

    private func miniRow(guess: String, target: String) -> some View {
        let statuses = GameEngine.evaluate(guess: guess, target: target)
        return HStack(spacing: 1) {
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(miniColor(statuses[i]))
                    .frame(width: 10, height: 10)
            }
        }
    }

    private func miniColor(_ status: TileStatus) -> Color {
        switch status {
        case .correct: Color(red: 0.42, green: 0.67, blue: 0.36)
        case .present: Color(red: 0.79, green: 0.71, blue: 0.34)
        case .absent:  Color(red: 0.47, green: 0.46, blue: 0.48)
        default:       Color(.systemGray5)
        }
    }
}
