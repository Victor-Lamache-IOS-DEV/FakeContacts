import Foundation

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

        guard digits.count <= 10 else {
            return real.sorted(by: nameOrder)
        }

        let fake = forcedContacts.sorted(by: nameOrder)

        if digits.count >= triggerDigits {
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
