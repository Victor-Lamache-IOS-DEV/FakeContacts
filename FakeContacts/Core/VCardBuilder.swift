import Foundation

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
