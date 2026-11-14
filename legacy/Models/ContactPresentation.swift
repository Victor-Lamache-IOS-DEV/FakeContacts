import Foundation

// MARK: - Resolved contact data shown on a detail screen

struct ContactPresentation {
    let phoneNumbers: [ContactField]
    let emailAddresses: [ContactField]
    let birthday: DateComponents?
    let birthdayText: String?
    let note: String
    let appliedTrick: Bool
}

// MARK: - Search

enum ContactSearch {
    static func results(
        contacts: [Contact],
        query: String,
        forcedContacts: [Contact],
        triggerDigits: Int,
        searchTrickArmed: Bool
    ) -> [Contact] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return contacts.sorted(by: nameOrder)
        }

        let digits = trimmed.filter(\.isNumber)
        let hasLetters = trimmed.rangeOfCharacter(from: .letters) != nil
        let isDigitQuery = !digits.isEmpty && !hasLetters
        let normalizedQuery = trimmed.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )

        let real = contacts.filter { contact in
            if isDigitQuery {
                return contact.phoneNumbers.contains {
                    $0.value.filter(\.isNumber).contains(digits)
                }
            }

            let searchable = [
                contact.name,
                contact.organizationName,
                contact.emailAddresses.map(\.value).joined(separator: " "),
                contact.phoneNumbers.map(\.value).joined(separator: " ")
            ]
                .joined(separator: " ")
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

            return searchable.contains(normalizedQuery)
        }

        guard searchTrickArmed, isDigitQuery else {
            return real.sorted(by: nameOrder)
        }

        guard digits.count <= triggerDigits else {
            return real.sorted(by: nameOrder)
        }

        let fake = forcedContacts.sorted(by: nameOrder)

        if digits.count == triggerDigits {
            return fake
        }

        return (real + fake).sorted(by: nameOrder)
    }

    private static func nameOrder(_ lhs: Contact, _ rhs: Contact) -> Bool {
        let comparison = lhs.name.localizedStandardCompare(rhs.name)
        if comparison == .orderedSame {
            return lhs.id < rhs.id
        }
        return comparison == .orderedAscending
    }
}

// MARK: - System actions

enum ContactAction {
    private static let phoneCharacters = CharacterSet(charactersIn: "0123456789+*#")

    static func phoneURL(_ value: String) -> URL? {
        makeURL(scheme: "tel", target: value, allowed: phoneCharacters)
    }

    static func messageURL(_ value: String) -> URL? {
        makeURL(scheme: "sms", target: value, allowed: phoneCharacters)
    }

    static func mailURL(_ value: String) -> URL? {
        makeURL(scheme: "mailto", target: value, allowed: nil)
    }

    static func faceTimeURL(_ value: String) -> URL? {
        makeURL(scheme: "facetime", target: value, allowed: nil)
    }

    private static func makeURL(
        scheme: String,
        target: String,
        allowed: CharacterSet?
    ) -> URL? {
        var value = target.trimmingCharacters(in: .whitespacesAndNewlines)
        if let allowed {
            value = String(value.unicodeScalars.filter { allowed.contains($0) })
        }

        guard !value.isEmpty else { return nil }

        var components = URLComponents()
        components.scheme = scheme
        components.path = value
        return components.url
    }
}

// MARK: - vCard export

enum VCardBuilder {
    static func makeData(for contact: Contact, presentation: ContactPresentation) -> Data {
        var lines = [
            "BEGIN:VCARD",
            "VERSION:3.0",
            "PRODID:-//FakeContacts//Contacts//EN",
            "N:\(escape(contact.familyName));\(escape(contact.givenName));;;",
            "FN:\(escape(contact.name))"
        ]

        for phone in presentation.phoneNumbers {
            lines.append("TEL:\(escape(phone.value))")
        }

        for email in presentation.emailAddresses {
            lines.append("EMAIL:\(escape(email.value))")
        }

        if let birthday = vCardBirthday(presentation.birthday) {
            lines.append("BDAY:\(birthday)")
        }

        if !presentation.note.isEmpty {
            lines.append("NOTE:\(escape(presentation.note))")
        }

        lines.append("END:VCARD")
        return Data(lines.joined(separator: "\r\n").utf8)
    }

    static func temporaryFileURL(for contact: Contact, presentation: ContactPresentation) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ContactShares", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let url = directory.appendingPathComponent("\(UUID().uuidString).vcf")
        try makeData(for: contact, presentation: presentation).write(to: url, options: .atomic)
        return url
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
    }

    private static func vCardBirthday(_ components: DateComponents?) -> String? {
        guard let components,
              let month = components.month,
              let day = components.day else {
            return nil
        }

        if let year = components.year {
            return String(format: "%04d%02d%02d", year, month, day)
        }
        return String(format: "--%02d%02d", month, day)
    }
}
