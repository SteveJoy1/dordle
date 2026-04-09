import SwiftUI

struct TileView: View {
    let letter: Character?
    let status: TileStatus
    var isRevealing: Bool = false
    var revealDelay: Double = 0

    @State private var flipAngle: Double = 0

    /// Whether to display the colored (revealed) face of the tile.
    /// True when: the flip has passed 90 degrees, OR the tile is a
    /// non-animating submitted tile (correct/present/absent without reveal).
    private var showColored: Bool {
        if isRevealing { return flipAngle >= 90 }
        // Static submitted tile — show colors immediately
        switch status {
        case .correct, .present, .absent: return true
        default: return false
        }
    }

    // MARK: - Colors

    private func fill(for s: TileStatus) -> Color {
        switch s {
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
        default:       fill(for: status)
        }
    }

    private var foreground: Color {
        showColored ? .white : Color(.label)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            if showColored {
                // Colored face
                RoundedRectangle(cornerRadius: 3)
                    .fill(fill(for: status))
                RoundedRectangle(cornerRadius: 3)
                    .stroke(fill(for: status), lineWidth: 2)
            } else {
                // Uncolored face
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.clear)
                RoundedRectangle(cornerRadius: 3)
                    .stroke(isRevealing ? Color(.systemGray2) : border, lineWidth: 2)
            }

            if let letter {
                Text(String(letter))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(foreground)
                    .scaleEffect(y: isRevealing && flipAngle >= 90 ? -1 : 1)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .rotation3DEffect(
            .degrees(isRevealing ? flipAngle : 0),
            axis: (x: 1, y: 0, z: 0)
        )
        .onChange(of: isRevealing) { _, revealing in
            if revealing {
                flipAngle = 0
                withAnimation(.easeIn(duration: 0.35).delay(revealDelay)) {
                    flipAngle = 90
                }
                withAnimation(.easeOut(duration: 0.35).delay(revealDelay + 0.35)) {
                    flipAngle = 180
                }
            } else {
                flipAngle = 0
            }
        }
    }
}
