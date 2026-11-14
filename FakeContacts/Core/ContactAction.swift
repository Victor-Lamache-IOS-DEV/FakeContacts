import Foundation

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
