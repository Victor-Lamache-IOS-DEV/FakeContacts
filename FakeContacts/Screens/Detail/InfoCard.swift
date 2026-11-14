import SwiftUI

struct InfoCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardFill, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var trailingIcon: String?
    var valueColor: Color = .white

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 17))
                    .foregroundStyle(valueColor)
            }

            Spacer(minLength: 0)

            if let trailingIcon {
                Image(systemName: trailingIcon)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.link)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
