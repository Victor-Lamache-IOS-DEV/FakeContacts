import SwiftUI
import UIKit

struct AvatarView: View {
    let contact: Contact
    let size: CGFloat
    var posterStyle: Bool = false

    var body: some View {
        Group {
            if let data = contact.imageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle()
                        .fill(
                            posterStyle
                                ? Color.white.opacity(0.16)
                                : Color(uiColor: .tertiarySystemFill)
                        )

                    Circle()
                        .strokeBorder(
                            posterStyle
                                ? Color.white.opacity(0.35)
                                : Color.primary.opacity(0.06),
                            lineWidth: 0.5
                        )

                    Text(contact.initials)
                        .font(.system(
                            size: max(13, size * (posterStyle ? 0.38 : 0.4)),
                            weight: .medium
                        ))
                        .foregroundStyle(
                            posterStyle
                                ? Color.white
                                : Color(uiColor: .secondaryLabel)
                        )
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}
