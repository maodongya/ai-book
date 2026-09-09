import SwiftUI

enum BookPageTurnDirection {
    case forward
    case backward
}

/// A single sheet that curls away from the spine with front/back faces and fold shading.
struct BookPageTurnSheet<Front: View>: View {
    let progress: CGFloat
    let direction: BookPageTurnDirection
    let width: CGFloat
    let height: CGFloat
    @ViewBuilder var front: () -> Front

    private var clampedProgress: CGFloat { min(max(progress, 0), 1) }
    private var angle: Double { Double(clampedProgress) * 180 }
    private var hingeAnchor: UnitPoint {
        direction == .forward ? .leading : .trailing
    }

    var body: some View {
        ZStack(alignment: direction == .forward ? .trailing : .leading) {
            frontFace
            backFace
            foldShade
        }
        .frame(width: width, height: height, alignment: direction == .forward ? .trailing : .leading)
        .shadow(
            color: .black.opacity(0.10 + Double(clampedProgress) * 0.22),
            radius: 6 + clampedProgress * 18,
            x: direction == .forward ? -10 * clampedProgress : 10 * clampedProgress,
            y: 4 + clampedProgress * 6
        )
    }

    private var frontFace: some View {
        front()
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .brightness(-Double(clampedProgress) * 0.04)
            .rotation3DEffect(
                .degrees(direction == .forward ? -angle : angle),
                axis: (x: 0, y: 1, z: 0),
                anchor: hingeAnchor,
                perspective: 0.42
            )
            .opacity(angle < 89.5 ? 1 : 0)
            .zIndex(2)
    }

    private var backFace: some View {
        pageReverseSurface
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .rotation3DEffect(
                .degrees(direction == .forward ? 180 - angle : angle - 180),
                axis: (x: 0, y: 1, z: 0),
                anchor: hingeAnchor,
                perspective: 0.42
            )
            .opacity(angle >= 89.5 ? 1 : 0)
            .zIndex(1)
    }

    private var pageReverseSurface: some View {
        ZStack {
            LinearGradient(
                colors: [
                    BookTheme.pageRight.opacity(0.96),
                    BookTheme.pageLeft.opacity(0.88),
                    BookTheme.pageEdge.opacity(0.72),
                ],
                startPoint: direction == .forward ? .leading : .trailing,
                endPoint: direction == .forward ? .trailing : .leading
            )
            LinearGradient(
                colors: [
                    Color.black.opacity(0.16),
                    Color.clear,
                    Color.white.opacity(0.10),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            BookInterface.HeaderOrnament()
                .opacity(0.35)
                .padding(.top, 8)
        }
        .bookPaperTexture()
    }

    private var foldShade: some View {
        let peak = Double(min(clampedProgress, 1 - clampedProgress) * 2.2)

        return LinearGradient(
            colors: [
                Color.black.opacity(0.42 * peak),
                Color.black.opacity(0.14 * peak),
                Color.clear,
            ],
            startPoint: direction == .forward ? .leading : .trailing,
            endPoint: direction == .forward ? .trailing : .leading
        )
        .frame(width: 48, height: height)
        .blur(radius: 2)
        .opacity(peak > 0.04 ? 1 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: direction == .forward ? .leading : .trailing)
        .allowsHitTesting(false)
        .zIndex(3)
    }
}

/// Underneath spread revealed while the top sheet curls away.
struct BookSpreadRevealLayer<Spread: View>: View {
    let progress: CGFloat
    @ViewBuilder var spread: () -> Spread

    private var clampedProgress: CGFloat { min(max(progress, 0), 1) }

    var body: some View {
        spread()
            .scaleEffect(0.988 + clampedProgress * 0.012, anchor: .center)
            .opacity(min(1, clampedProgress * 1.25))
            .brightness(-0.03 + clampedProgress * 0.03)
    }
}

extension Animation {
    static var bookPageTurn: Animation {
        .spring(response: 0.58, dampingFraction: 0.86, blendDuration: 0.08)
    }
}
