import SwiftUI
import UIKit

struct ContactAvatar: View {
    enum Style {
        case solid
        case glass
    }

    let image: UIImage?
    let initials: String
    let size: CGFloat
    var style: Style = .solid

    var body: some View {
        Color.clear
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    initialsView
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var initialsView: some View {
        switch style {
        case .solid:
            ZStack {
                Circle()
                    .fill(Theme.listAvatarFill)
                Text(initials)
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(.white)
            }
        case .glass:
            ZStack {
                Circle()
                    .glassEffect(.regular, in: .circle)
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.45), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1.5
                    )
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
    }
}
