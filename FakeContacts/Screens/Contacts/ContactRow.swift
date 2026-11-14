import SwiftUI

struct ContactRow: View {
    let contact: Contact
    var phone: String?

    var body: some View {
        HStack(spacing: 12) {
            ContactAvatar(image: contact.thumbnail, initials: contact.initials, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(contact.name)
                    .font(.system(size: 17))
                    .foregroundStyle(.white)

                if let phone {
                    Text(formatPhone(phone))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 4)

            Rectangle()
                .fill(Theme.separator)
                .frame(height: 0.5)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black)
    }
}
