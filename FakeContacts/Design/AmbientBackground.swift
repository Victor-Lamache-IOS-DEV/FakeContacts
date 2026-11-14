import SwiftUI
import UIKit

struct AmbientBackground: View {
    let image: UIImage?

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
                            Color(red: 0.55, green: 0.62, blue: 0.78),
                            Color(red: 0.30, green: 0.34, blue: 0.56),
                            Color(red: 0.10, green: 0.10, blue: 0.28)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .overlay {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.18), .black.opacity(0.5)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .clipped()
            .ignoresSafeArea()
    }
}
