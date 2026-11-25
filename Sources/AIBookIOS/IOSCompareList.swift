import SwiftUI

/// iPhone 上的对照：一块里上原文、下译文或讲解。不用左右分栏。
struct IOSCompareList: View {
    var pairs: [(source: String, other: String)]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(Array(pairs.enumerated()), id: \.offset) { _, pair in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(pair.source)
                            .foregroundStyle(IOSPaper.ink)
                        Text(pair.other)
                            .foregroundStyle(IOSPaper.inkMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.white.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(20)
        }
    }
}
