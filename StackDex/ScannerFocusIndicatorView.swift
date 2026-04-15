import SwiftUI

struct ScannerFocusIndicatorView: View {
    enum State {
        case idle
        case active

        var tint: Color {
            switch self {
            case .idle:
                return .white.opacity(0.72)
            case .active:
                return .yellow
            }
        }

        var scale: CGFloat {
            switch self {
            case .idle:
                return 1
            case .active:
                return 0.92
            }
        }
    }

    let state: State

    init(state: State) {
        self.state = state
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(state.tint, lineWidth: 2)

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(state.tint.opacity(0.35), lineWidth: 1)
                .padding(7)

            Circle()
                .fill(state.tint)
                .frame(width: 7, height: 7)
        }
        .scaleEffect(state.scale)
        .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
        .animation(.easeOut(duration: 0.18), value: state.scale)
        .allowsHitTesting(false)
    }
}
