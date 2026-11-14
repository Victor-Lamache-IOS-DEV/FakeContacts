import Foundation

// MARK: - Labeled contact value

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

// MARK: - Contact

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

    var initials: String {
        let parts = name.split(whereSeparator: { $0.isWhitespace }).prefix(2)
        let result = parts.compactMap { $0.first.map(String.init) }.joined()
        return result.isEmpty ? "#" : result.uppercased()
    }

    var birthdayText: String? { formatBirthday(birthday) }
}

func formatBirthday(_ components: DateComponents?) -> String? {
    guard let components, let month = components.month, let day = components.day else {
        return nil
    }

    var dateComponents = DateComponents()
    dateComponents.month = month
    dateComponents.day = day
    dateComponents.year = components.year ?? 2000

    guard let date = Calendar.current.date(from: dateComponents) else { return nil }

    let formatter = DateFormatter()
    formatter.locale = .current
    if components.year != nil {
        formatter.dateStyle = .long
        formatter.timeStyle = .none
    } else {
        formatter.setLocalizedDateFormatFromTemplate("MMMMd")
    }
    return formatter.string(from: date)
}

// MARK: - Contact group

struct ContactGroup: Identifiable, Hashable {
    let id: String
    let name: String
}

// MARK: - Labels

enum ContactLabel {
    static func localized(_ rawLabel: String?) -> String {
        guard let rawLabel, !rawLabel.isEmpty else {
            return NSLocalizedString("other", comment: "Default contact field label")
        }

        if rawLabel.hasPrefix("_$!<"), rawLabel.hasSuffix(">!$_") {
            let inner = rawLabel.dropFirst(4).dropLast(4)
            return localizedSystemLabel(String(inner))
        }

        return rawLabel
    }

    private static func localizedSystemLabel(_ label: String) -> String {
        switch label.lowercased() {
        case "mobile": return NSLocalizedString("mobile", comment: "Phone label")
        case "home": return NSLocalizedString("home", comment: "Contact field label")
        case "work": return NSLocalizedString("work", comment: "Contact field label")
        case "other": return NSLocalizedString("other", comment: "Contact field label")
        case "main": return NSLocalizedString("main", comment: "Phone label")
        case "home fax": return NSLocalizedString("home fax", comment: "Phone label")
        case "work fax": return NSLocalizedString("work fax", comment: "Phone label")
        case "pager": return NSLocalizedString("pager", comment: "Phone label")
        case "iphone": return NSLocalizedString("iPhone", comment: "Phone label")
        case "apple watch": return NSLocalizedString("Apple Watch", comment: "Phone label")
        case "school": return NSLocalizedString("school", comment: "Contact field label")
        case "icloud": return NSLocalizedString("iCloud", comment: "Contact field label")
        case "anniversary": return NSLocalizedString("anniversary", comment: "Date label")
        case "birthday": return NSLocalizedString("birthday", comment: "Date label")
        default: return label
        }
    }
}

// MARK: - Phone display

func formatPhone(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    let digits = raw.filter(\.isNumber)

    guard !digits.isEmpty else { return trimmed }

    if raw.contains("+") && digits.hasPrefix("33") && digits.count == 11 {
        let national = String(digits.dropFirst(2))
        let first = national.prefix(1)
        let rest = national.dropFirst()
        let pairs = stride(from: 0, to: rest.count, by: 2).map { offset -> String in
            let start = rest.index(rest.startIndex, offsetBy: offset)
            let end = rest.index(start, offsetBy: min(2, rest.distance(from: start, to: rest.endIndex)))
            return String(rest[start..<end])
        }
        return "+33 \(first) \(pairs.joined(separator: " "))".trimmingCharacters(in: .whitespaces)
    }

    if digits.hasPrefix("0") && digits.count == 10 {
        let pairs = stride(from: 0, to: digits.count, by: 2).map { offset -> String in
            let start = digits.index(digits.startIndex, offsetBy: offset)
            let end = digits.index(start, offsetBy: 2)
            return String(digits[start..<end])
        }
        return pairs.joined(separator: " ")
    }

    // Keep international dialling information, then group the remaining digits.
    let prefix = raw.hasPrefix("+") ? "+" : ""
    let grouped = stride(from: 0, to: digits.count, by: 2).map { offset -> String in
        let start = digits.index(digits.startIndex, offsetBy: offset)
        let end = digits.index(start, offsetBy: min(2, digits.distance(from: start, to: digits.endIndex)))
        return String(digits[start..<end])
    }
    return prefix + grouped.joined(separator: " ")
}
