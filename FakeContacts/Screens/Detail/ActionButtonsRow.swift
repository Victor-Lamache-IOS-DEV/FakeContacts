import SwiftUI

struct DetailActionButton: View {
    let icon: String
    let title: LocalizedStringKey
    let showsTitle: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))

                if showsTitle {
                    Text(title)
                        .font(.system(size: 13))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: showsTitle ? .infinity : nil)
            .frame(width: showsTitle ? nil : 64, height: showsTitle ? 62 : 64)
            .glassEffect(
                .regular.interactive(),
                in: RoundedRectangle(cornerRadius: showsTitle ? 22 : 32, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
    }
}
