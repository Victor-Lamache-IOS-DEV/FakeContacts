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
                        colors: [
                            Color(hue: hue, saturation: 0.42, brightness: 0.44),
                            Color(hue: hue, saturation: 0.50, brightness: 0.18),
                            Color(hue: (hue + 0.08).truncatingRemainder(dividingBy: 1), saturation: 0.55, brightness: 0.06)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
            .overlay {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.55), .black],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .clipped()
            .ignoresSafeArea()
    }

    private var hue: Double {
        let hash = seed.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7fff_ffff }
        return Double(hash % 360) / 360
    }
}
