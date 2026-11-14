import SwiftUI
import UIKit

struct AmbientBackground: View {
    let image: UIImage?
    let seed: String

    var body: some View {
        Color.black
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .blur(radius: 60)
                        .opacity(0.85)
                } else {
                    LinearGradient(
                        colors: [tint(brightness: 0.55), tint(brightness: 0.3)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
            .overlay {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.6), .black],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .clipped()
            .ignoresSafeArea()
    }

    private func tint(brightness: Double) -> Color {
        Color(hue: hue, saturation: 0.45, brightness: brightness)
    }

    private var hue: Double {
        let hash = seed.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7fff_ffff }
        return Double(hash % 360) / 360
    }
}
