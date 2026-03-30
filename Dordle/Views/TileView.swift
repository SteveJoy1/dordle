import SwiftUI

struct TileView: View {
    let letter: Character?
    let status: TileStatus

    private var fill: Color {
        switch status {
        case .correct: Color(red: 0.42, green: 0.67, blue: 0.36)
        case .present: Color(red: 0.79, green: 0.71, blue: 0.34)
        case .absent:  Color(red: 0.47, green: 0.46, blue: 0.48)
        default:       .clear
        }
    }

    private var border: Color {
        switch status {
        case .typed:   Color(.systemGray2)
        case .empty:   Color(.systemGray4)
        default:       fill
        }
    }

    private var foreground: Color {
        switch status {
        case .correct, .present, .absent: .white
        default: Color(.label)
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(fill)
            RoundedRectangle(cornerRadius: 3)
                .stroke(border, lineWidth: 2)
            if let letter {
                Text(String(letter))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(foreground)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
