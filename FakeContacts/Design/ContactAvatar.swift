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
                    .fill(.white.opacity(0.09))

                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.35), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size * 0.7, height: size * 0.34)
                    .offset(y: -size * 0.27)

                Circle()
                    .strokeBorder(Color.black.opacity(0.25), lineWidth: 5)
                    .blur(radius: 7)
                    .offset(y: 3)

                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.55), .clear, Color.white.opacity(0.06)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1.5
                    )

                Text(initials)
                    .font(.system(size: size * 0.42, weight: .medium))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            }
            .clipShape(Circle())
        }
    }
}
