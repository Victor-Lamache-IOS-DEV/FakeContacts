import SwiftUI

struct MyCardRow: View {
    let contact: Contact

    var body: some View {
        HStack(spacing: 12) {
            ContactAvatar(image: contact.thumbnail, initials: contact.initials, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(contact.name)
                    .font(.system(size: 17))
                    .foregroundStyle(.white)

                Text("My Card")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
