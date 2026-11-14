import UIKit

struct ContactListSection: Identifiable {
    let collationIndex: Int
    let title: String
    let contacts: [Contact]

    var id: String { title }

    static func make(from contacts: [Contact]) -> [ContactListSection] {
        let collation = UILocalizedIndexedCollation.current()
        var buckets: [Int: [Contact]] = [:]

        for contact in contacts {
            let item = ContactCollationItem(contact: contact)
            let index = collation.section(
                for: item,
                collationStringSelector: #selector(getter: ContactCollationItem.collationName)
            )
            buckets[index, default: []].append(contact)
        }

        return buckets.keys.sorted().map { index in
            let sorted = (buckets[index] ?? []).sorted {
                let comparison = $0.name.localizedStandardCompare($1.name)
                return comparison == .orderedSame ? $0.id < $1.id : comparison == .orderedAscending
            }
            return ContactListSection(
                collationIndex: index,
                title: collation.sectionTitles[index],
                contacts: sorted
            )
        }
    }
}

final class ContactCollationItem: NSObject {
    let contact: Contact

    init(contact: Contact) {
        self.contact = contact
        super.init()
    }

    @objc var collationName: String { contact.name }
}
