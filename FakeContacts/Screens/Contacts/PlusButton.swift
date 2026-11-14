import SwiftUI
import UIKit

struct PlusButton: View {
    let isArmed: Bool
    let onDoubleTap: () -> Void

    var body: some View {
        Image(systemName: "plus")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(isArmed ? Theme.link : Color.white)
            .frame(width: 52, height: 52)
            .contentShape(Circle())
            .glassEffect(.regular.interactive(), in: .circle)
            .onTapGesture(count: 2) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onDoubleTap()
            }
            .accessibilityLabel(Text("Add Contact"))
            .accessibilityAddTraits(.isButton)
    }
}
