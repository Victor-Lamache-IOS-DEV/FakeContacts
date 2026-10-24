import Foundation
import Contacts
import UIKit

// MARK: - Contact
struct Contact: Identifiable {
    let id: UUID
    var name: String
    var phone: String
    var note: String
    var thumbnailImage: UIImage?
    var email: String = ""
    var birthday: String = ""
    var forcedSuffix: String? = nil
    var forcedSearchNote: String? = nil
    var forcedEmail: String? = nil
    var forcedBirthday: String? = nil

    init(name: String, phone: String, note: String, thumbnailImage: UIImage? = nil,
         email: String = "", birthday: String = "",
         forcedSuffix: String? = nil, forcedSearchNote: String? = nil,
         forcedEmail: String? = nil, forcedBirthday: String? = nil) {
        self.id = UUID()
        self.name = name; self.phone = phone; self.note = note
        self.thumbnailImage = thumbnailImage
        self.email = email; self.birthday = birthday
        self.forcedSuffix = forcedSuffix; self.forcedSearchNote = forcedSearchNote
        self.forcedEmail = forcedEmail; self.forcedBirthday = forcedBirthday
    }
}

// MARK: - Trick 1: Profile
struct TrickProfile: Identifiable, Codable {
    var id = UUID()
    var fakePhone: String = ""
    var fakeNote: String = ""
    var fakeEmail: String = ""
    var fakeBirthday: String = ""
}

// MARK: - Trick 2: Forced Contact
struct ForcedContact: Identifiable, Codable {
    var id = UUID()
    var fakeName: String = ""
    var phoneSuffix: String = ""
    var fakeNote: String = ""
    var fakeEmail: String = ""
    var fakeBirthday: String = ""
}

// MARK: - TrickEngine
class TrickEngine: ObservableObject {
    // Trick 1
    @Published var isArmed: Bool = false
    @Published var profiles: [TrickProfile] = []
    @Published var currentIndex: Int = 0
    @Published var minSeconds: Double = 14

    // Trick 2
    @Published var searchTrickArmed: Bool = false
    @Published var forcedContacts: [ForcedContact] = []
    @Published var searchTriggerDigits: Int = 4

    // Last opened — session only, not persisted
    @Published var lastOpenedName: String = ""
    @Published var lastOpenedPhone: String = ""

    init() { load() }

    func currentProfile() -> TrickProfile? {
        guard isArmed, !profiles.isEmpty else { return nil }
        guard currentIndex < profiles.count else {
            DispatchQueue.main.async { self.isArmed = false; self.currentIndex = 0 }
            return nil
        }
        return profiles[currentIndex]
    }

    func advance() {
        currentIndex += 1
        if currentIndex >= profiles.count { isArmed = false; currentIndex = 0 }
        save()
    }

    func arm()    { isArmed = true;  currentIndex = 0; save() }
    func disarm() { isArmed = false; currentIndex = 0; save() }

    func save() {
        let d = UserDefaults.standard
        d.set(isArmed,             forKey: "trickArmed")
        d.set(currentIndex,        forKey: "trickIndex")
        d.set(minSeconds,          forKey: "trickMinSeconds")
        d.set(searchTrickArmed,    forKey: "searchTrickArmed")
        d.set(searchTriggerDigits, forKey: "searchTriggerDigits")
        if let data = try? JSONEncoder().encode(profiles) { d.set(data, forKey: "trickProfiles") }
        if let data = try? JSONEncoder().encode(forcedContacts) { d.set(data, forKey: "forcedContacts") }
    }

    func load() {
        let d = UserDefaults.standard
        isArmed             = d.bool(forKey: "trickArmed")
        currentIndex        = d.integer(forKey: "trickIndex")
        minSeconds          = d.object(forKey: "trickMinSeconds") as? Double ?? 14
        searchTrickArmed    = d.bool(forKey: "searchTrickArmed")
        searchTriggerDigits = d.object(forKey: "searchTriggerDigits") as? Int ?? 4
        if let data = d.data(forKey: "trickProfiles"),
           let decoded = try? JSONDecoder().decode([TrickProfile].self, from: data) { profiles = decoded }
        if let data = d.data(forKey: "forcedContacts"),
           let decoded = try? JSONDecoder().decode([ForcedContact].self, from: data) { forcedContacts = decoded }
    }
}

// MARK: - ContactStore
class ContactStore: ObservableObject {
    @Published var contacts: [Contact] = []
    @Published var permissionDenied: Bool = false

    func requestAndLoad() {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, _ in
            DispatchQueue.main.async {
                if granted { self.loadContacts(store: store) }
                else { self.permissionDenied = true }
            }
        }
    }

    private func loadContacts(store: CNContactStore) {
        let keys = [CNContactGivenNameKey, CNContactFamilyNameKey,
                    CNContactPhoneNumbersKey, CNContactThumbnailImageDataKey,
                    CNContactEmailAddressesKey, CNContactBirthdayKey] as [CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)
        var loaded: [Contact] = []
        try? store.enumerateContacts(with: request) { cn, _ in
            let name = [cn.givenName, cn.familyName]
                .filter { !$0.isEmpty }.joined(separator: " ")
            guard !name.isEmpty else { return }
            let phone = cn.phoneNumbers.first?.value.stringValue ?? ""
            let email = cn.emailAddresses.first?.value as String? ?? ""
            let image = cn.thumbnailImageData.flatMap { UIImage(data: $0) }
            var birthday = ""
            if let bday = cn.birthday, let month = bday.month, let day = bday.day {
                birthday = String(format: "%02d / %02d", day, month)
                if let year = bday.year { birthday += " / \(year)" }
            }
            loaded.append(Contact(name: name, phone: phone, note: "",
                                  thumbnailImage: image, email: email, birthday: birthday))
        }
        DispatchQueue.main.async {
            self.contacts = loaded.sorted { $0.name.lowercased() < $1.name.lowercased() }
        }
    }
}

// MARK: - Format Phone
func formatPhone(_ raw: String) -> String {
    let digits = raw.filter { $0.isNumber }
    
    // Handle French International (33 + 9 digits)
    if digits.hasPrefix("33") && digits.count == 11 {
        let start = "+33"
        let second = digits.index(digits.startIndex, offsetBy: 2)
        let restStart = digits.index(digits.startIndex, offsetBy: 3)
        
        let secondDigit = String(digits[second])
        let rest = String(digits[restStart...])
        
        var formattedRest = ""
        for (i, char) in rest.enumerated() {
            if i > 0 && i % 2 == 0 { formattedRest += " " }
            formattedRest.append(char)
        }
        return "\(start) \(secondDigit) \(formattedRest)"
    }
    
    // Handle French Local (0 + 9 digits)
    if digits.hasPrefix("0") && digits.count == 10 {
        var result = ""
        for (i, char) in digits.enumerated() {
            if i > 0 && i % 2 == 0 { result += " " }
            result.append(char)
        }
        return result
    }
    
    // Fallback: Pair grouping
    var result = ""
    for (i, char) in digits.enumerated() {
        if i > 0 && i % 2 == 0 { result += " " }
        result.append(char)
    }
    return result
}
