import Foundation

struct MyCardProfile: Codable, Equatable {
    var name: String = ""
    var phone: String = ""
    var email: String = ""
    var photo: Data? = nil

    var initials: String {
        let parts = name.split(whereSeparator: { $0.isWhitespace }).prefix(2)
        let result = parts.compactMap { $0.first.map(String.init) }.joined()
        return result.isEmpty ? "#" : result.uppercased()
    }
}
