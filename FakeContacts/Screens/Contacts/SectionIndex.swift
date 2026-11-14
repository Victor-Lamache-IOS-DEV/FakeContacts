import SwiftUI
import UIKit

struct SectionIndex: View {
    let letters: [String]
    let onSelect: (Int) -> Void

    private let rowHeight: CGFloat = 13

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(letters.enumerated()), id: \.offset) { _, letter in
                Text(letter)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.link)
                    .frame(width: 18, height: rowHeight)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let index = Int(value.location.y / rowHeight)
                    onSelect(min(max(index, 0), letters.count - 1))
                }
        )
        .accessibilityHidden(true)
    }
}
