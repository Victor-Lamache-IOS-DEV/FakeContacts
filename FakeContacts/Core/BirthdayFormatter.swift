import Foundation

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

func birthdayComponents(from raw: String) -> DateComponents? {
    let digits = raw.filter(\.isNumber)

    guard digits.count == 4 || digits.count == 8 else { return nil }

    let day = Int(digits.prefix(2)) ?? 0
    let monthStart = digits.index(digits.startIndex, offsetBy: 2)
    let month = Int(digits[monthStart..<digits.index(monthStart, offsetBy: 2)]) ?? 0

    guard (1...12).contains(month), (1...31).contains(day) else { return nil }

    var components = DateComponents()
    components.day = day
    components.month = month

    if digits.count == 8 {
        let yearStart = digits.index(digits.startIndex, offsetBy: 4)
        components.year = Int(digits[yearStart...])
    }

    return components
}
