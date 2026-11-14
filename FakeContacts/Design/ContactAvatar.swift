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
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundStyle(.white)
            }
        case .glass:
            ZStack {
                Circle()
                    .fill(.white.opacity(0.14))
                Circle()
                    .glassEffect(.prominent, in: .circle)
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.7), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                Text(initials)
                    .font(.system(size: size * 0.42, weight: .medium))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
            }
        }
    }
}
