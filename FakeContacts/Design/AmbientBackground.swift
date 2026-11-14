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
                        stops: [
                            .init(color: Color(red: 0.502, green: 0.553, blue: 0.580), location: 0.0),
                            .init(color: Color(red: 0.573, green: 0.596, blue: 0.659), location: 0.15),
                            .init(color: Color(red: 0.553, green: 0.545, blue: 0.631), location: 0.30),
                            .init(color: Color(red: 0.416, green: 0.380, blue: 0.502), location: 0.45),
                            .init(color: Color(red: 0.204, green: 0.141, blue: 0.286), location: 0.60),
                            .init(color: Color(red: 0.118, green: 0.075, blue: 0.200), location: 0.75),
                            .init(color: Color(red: 0.027, green: 0.020, blue: 0.075), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .clipped()
            .ignoresSafeArea()
    }
}
