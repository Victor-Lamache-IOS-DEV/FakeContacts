import Foundation

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

    let prefix = raw.hasPrefix("+") ? "+" : ""
    let grouped = stride(from: 0, to: digits.count, by: 2).map { offset -> String in
        let start = digits.index(digits.startIndex, offsetBy: offset)
        let end = digits.index(start, offsetBy: min(2, digits.distance(from: start, to: digits.endIndex)))
        return String(digits[start..<end])
    }
    return prefix + grouped.joined(separator: " ")
}
