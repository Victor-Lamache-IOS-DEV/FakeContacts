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

                Circle()
                    .strokeBorder(Color.black.opacity(0.4), lineWidth: 6)
                    .blur(radius: 4)

                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.35), .clear],
                            startPoint: .top,
                            endPoint: .center
                        ),
                        lineWidth: 1
                    )

                Text(initials)
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            }
            .shadow(color: .black.opacity(0.3), radius: size * 0.05, y: size * 0.03)
        case .glass:
            ZStack {
                Circle()
                    .glassEffect(.regular, in: .circle)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )

                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.5), .clear, Color.white.opacity(0.08)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1.5
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
