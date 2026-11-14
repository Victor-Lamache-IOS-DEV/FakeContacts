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
                    .fill(.white.opacity(0.22))
                    .glassEffect(.regular, in: .circle)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.32), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .clear, Color.black.opacity(0.18)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.85), .clear, Color.black.opacity(0.25)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 3
                    )

                Text(initials)
                    .font(.system(size: size * 0.42, weight: .medium))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
            }
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.45), radius: 28, y: 14)
        }
    }
}
