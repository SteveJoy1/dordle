import SwiftUI

struct KeyboardView: View {
    let states1: [Character: TileStatus]
    let states2: [Character: TileStatus]
    let onKey: (String) -> Void

    private let rows: [[String]] = [
        ["Q","W","E","R","T","Y","U","I","O","P"],
        ["A","S","D","F","G","H","J","K","L"],
        ["ENTER","Z","X","C","V","B","N","M","DEL"],
    ]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(rows.indices, id: \.self) { i in
                HStack(spacing: 4) {
                    if i == 1 { Spacer(minLength: 12) }
                    ForEach(rows[i], id: \.self) { key in
                        keyButton(key)
                    }
                    if i == 1 { Spacer(minLength: 12) }
                }
            }
        }
    }

    @ViewBuilder
    private func keyButton(_ key: String) -> some View {
        let isWide = key.count > 1
        let ch = key.count == 1 ? Character(key) : Character(" ")
        let s1 = key.count == 1 ? states1[ch] : nil
        let s2 = key.count == 1 ? states2[ch] : nil
        let hasColor = s1 != nil || s2 != nil

        Button { onKey(key) } label: {
            ZStack {
                if hasColor {
                    HStack(spacing: 0) {
                        Rectangle().fill(colorFor(s1))
                        Rectangle().fill(colorFor(s2))
                    }
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray4))
                }

                if key == "DEL" {
                    Image(systemName: "delete.backward")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(hasColor ? .white : Color(.label))
                } else if key == "ENTER" {
                    Image(systemName: "return")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(hasColor ? .white : Color(.label))
                } else {
                    Text(key)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(hasColor ? .white : Color(.label))
                }
            }
            .frame(minWidth: isWide ? 48 : 30, maxHeight: 52)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private func colorFor(_ status: TileStatus?) -> Color {
        switch status {
        case .correct: Color(red: 0.42, green: 0.67, blue: 0.36)
        case .present: Color(red: 0.79, green: 0.71, blue: 0.34)
        case .absent:  Color(red: 0.47, green: 0.46, blue: 0.48)
        default:       Color(.systemGray4)
        }
    }
}
