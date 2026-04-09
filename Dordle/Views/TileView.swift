import SwiftUI

struct TileView: View {
    let letter: Character?
    let status: TileStatus
    var isRevealing: Bool = false
    var revealDelay: Double = 0
    var isInvalid: Bool = false

    @State private var flipAngle: Double = 0

    private func startFlip() {
        flipAngle = 0
        withAnimation(.easeIn(duration: 0.2).delay(revealDelay)) {
            flipAngle = 90
        }
        withAnimation(.easeOut(duration: 0.2).delay(revealDelay + 0.2)) {
            flipAngle = 180
        }
    }

    private var showColored: Bool {
        if isRevealing { return flipAngle >= 90 }
        switch status {
        case .correct, .present, .absent: return true
        default: return false
        }
    }

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
        if showColored { return .white }
        if isInvalid { return .red }
        return Color(.label)
    }

    var body: some View {
        ZStack {
            if showColored {
                RoundedRectangle(cornerRadius: 3)
                    .fill(fill(for: status))
                RoundedRectangle(cornerRadius: 3)
                    .stroke(fill(for: status), lineWidth: 2)
            } else {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.clear)
                RoundedRectangle(cornerRadius: 3)
                    .stroke(isInvalid ? .red : (isRevealing ? Color(.systemGray2) : border), lineWidth: 2)
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
        .onAppear {
            if isRevealing {
                startFlip()
            }
        }
        .onChange(of: isRevealing) { _, revealing in
            if revealing {
                startFlip()
            } else {
                flipAngle = 0
            }
        }
    }
}
