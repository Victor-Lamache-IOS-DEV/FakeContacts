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
                            Color(red: 0.58, green: 0.62, blue: 0.65),
                            Color(red: 0.36, green: 0.39, blue: 0.46),
                            Color(red: 0.05, green: 0.05, blue: 0.09)
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
}
