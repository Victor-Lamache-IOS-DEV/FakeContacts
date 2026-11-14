import Foundation

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
