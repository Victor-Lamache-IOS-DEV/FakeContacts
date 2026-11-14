import Foundation
import UIKit

struct ContactField: Identifiable, Hashable {
    let id: UUID
    let label: String
    let value: String

    init(label: String, value: String) {
        self.id = UUID()
        self.label = label
        self.value = value
    }
}

struct Contact: Identifiable {
    let id: String
    let givenName: String
    let familyName: String
    let organizationName: String
    let name: String
    let phoneNumbers: [ContactField]
    let emailAddresses: [ContactField]
    let birthday: DateComponents?
    let note: String
    let imageData: Data?
    let isForced: Bool

    init(
        id: String,
        givenName: String = "",
        familyName: String = "",
        organizationName: String = "",
        name: String,
        phoneNumbers: [ContactField] = [],
        emailAddresses: [ContactField] = [],
        birthday: DateComponents? = nil,
        note: String = "",
        imageData: Data? = nil,
        isForced: Bool = false
    ) {
        self.id = id
        self.givenName = givenName
        self.familyName = familyName
        self.organizationName = organizationName
        self.name = name
        self.phoneNumbers = phoneNumbers
        self.emailAddresses = emailAddresses
        self.birthday = birthday
        self.note = note
        self.imageData = imageData
        self.isForced = isForced
    }

    var primaryPhone: ContactField? { phoneNumbers.first }
    var primaryEmail: ContactField? { emailAddresses.first }
    var thumbnail: UIImage? { imageData.flatMap { UIImage(data: $0) } }
    var birthdayText: String? { formatBirthday(birthday) }

    var initials: String {
        let parts = name.split(whereSeparator: { $0.isWhitespace }).prefix(2)
        let result = parts.compactMap { $0.first.map(String.init) }.joined()
        return result.isEmpty ? "#" : result.uppercased()
    }
}

struct ContactGroup: Identifiable, Hashable {
    let id: String
    let name: String
}
