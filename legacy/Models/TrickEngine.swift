import Combine
import Foundation
import UIKit
import AudioToolbox

// MARK: - Trick 1 profile

struct TrickProfile: Identifiable, Codable, Equatable {
    var id = UUID()
    var fakePhone: String = ""
    var fakeNote: String = ""
    var fakeEmail: String = ""
    var fakeBirthday: String = ""
}

// MARK: - Trick 2 forced contact

struct ForcedContact: Identifiable, Codable, Equatable {
    var id = UUID()
    var fakeName: String = ""
    var phoneSuffix: String = ""
    var fakeNote: String = ""
    var fakeEmail: String = ""
    var fakeBirthday: String = ""
}

// MARK: - Trick engine

final class TrickEngine: ObservableObject {
    @Published var isArmed: Bool = false { didSet { save() } }
    @Published var profiles: [TrickProfile] = [] {
        didSet {
            sanitizeSequence()
            save()
        }
    }
    @Published var currentIndex: Int = 0 { didSet { save() } }
    @Published var minSeconds: Double = 14 { didSet { save() } }

    @Published var searchTrickArmed: Bool = false { didSet { save() } }
    @Published var forcedContacts: [ForcedContact] = [] { didSet { save() } }
    @Published var searchTriggerDigits: Int = 4 { didSet { save() } }

    @Published var lastOpenedName: String = "" { didSet { save() } }
    @Published var lastOpenedPhone: String = "" { didSet { save() } }

    @Published var peekEnabled: Bool = true { didSet { save() } }
    @Published var peekSoundEnabled: Bool = true { didSet { save() } }
    @Published var peekHapticEnabled: Bool = true { didSet { save() } }

    private var isLoaded = false

    private enum Key {
        static let armed = "trickArmed"
        static let index = "trickIndex"
        static let minSeconds = "trickMinSeconds"
        static let searchArmed = "searchTrickArmed"
        static let triggerDigits = "searchTriggerDigits"
        static let lastName = "lastOpenedName"
        static let lastPhone = "lastOpenedPhone"
        static let peekEnabled = "peekEnabled"
        static let peekSound = "peekSoundEnabled"
        static let peekHaptic = "peekHapticEnabled"
        static let profiles = "trickProfiles"
        static let forcedContacts = "forcedContacts"
    }

    init() {
        load()
    }

    // MARK: Sequence

    var activeProfile: TrickProfile? {
        guard isArmed,
              !profiles.isEmpty,
              profiles.indices.contains(currentIndex) else { return nil }
        return profiles[currentIndex]
    }

    var sequenceStatus: String {
        guard isArmed else { return NSLocalizedString("Disarmed", comment: "Trick status") }
        guard !profiles.isEmpty else { return NSLocalizedString("No Profiles", comment: "Trick status") }
        return String(
            format: NSLocalizedString("Armed (%d of %d)", comment: "Trick sequence status"),
            currentIndex + 1,
            profiles.count
        )
    }

    func arm() {
        guard !profiles.isEmpty else { return }
        isArmed = true
        currentIndex = 0
    }

    func disarm() {
        isArmed = false
        currentIndex = 0
    }

    func resetSequence() {
        currentIndex = 0
    }

    func advance() {
        guard isArmed else { return }
        guard !profiles.isEmpty else {
            disarm()
            return
        }

        if currentIndex + 1 < profiles.count {
            currentIndex += 1
        } else {
            isArmed = false
            currentIndex = 0
        }
    }

    private func sanitizeSequence() {
        if profiles.isEmpty {
            isArmed = false
            currentIndex = 0
            return
        }

        if !profiles.indices.contains(currentIndex) {
            currentIndex = 0
        }
    }

    // MARK: Peek

    func markLastOpened(name: String, phone: String) {
        lastOpenedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        lastOpenedPhone = phone.filter(\.isNumber)
    }

    func triggerPeekFeedback() {
        if peekHapticEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        if peekSoundEnabled {
            AudioServicesPlaySystemSound(1104)
        }
    }

    // MARK: Forced search contacts

    func forcedSearchContacts(matchingDigits digits: String) -> [Contact] {
        let safeDigits = digits.filter(\.isNumber)

        return forcedContacts.compactMap { forced in
            let name = forced.fakeName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }

            let suffix = forced.phoneSuffix.filter(\.isNumber)
            let phoneValue = suffix.isEmpty ? safeDigits : safeDigits + suffix
            let phones = phoneValue.isEmpty
                ? []
                : [ContactField(label: "mobile", value: phoneValue)]

            let emailValue = forced.fakeEmail.trimmingCharacters(in: .whitespacesAndNewlines)
            let emails = emailValue.isEmpty
                ? []
                : [ContactField(label: "email", value: emailValue)]

            return Contact(
                id: "forced-\(forced.id.uuidString)",
                name: name,
                phoneNumbers: phones,
                emailAddresses: emails,
                birthday: birthdayComponents(from: forced.fakeBirthday),
                note: forced.fakeNote,
                isForced: true
            )
        }
    }

    // MARK: Persistence

    private func save() {
        guard isLoaded else { return }

        let defaults = UserDefaults.standard
        defaults.set(isArmed, forKey: Key.armed)
        defaults.set(currentIndex, forKey: Key.index)
        defaults.set(minSeconds, forKey: Key.minSeconds)
        defaults.set(searchTrickArmed, forKey: Key.searchArmed)
        defaults.set(searchTriggerDigits, forKey: Key.triggerDigits)
        defaults.set(lastOpenedName, forKey: Key.lastName)
        defaults.set(lastOpenedPhone, forKey: Key.lastPhone)
        defaults.set(peekEnabled, forKey: Key.peekEnabled)
        defaults.set(peekSoundEnabled, forKey: Key.peekSound)
        defaults.set(peekHapticEnabled, forKey: Key.peekHaptic)

        if let data = try? JSONEncoder().encode(profiles) {
            defaults.set(data, forKey: Key.profiles)
        }
        if let data = try? JSONEncoder().encode(forcedContacts) {
            defaults.set(data, forKey: Key.forcedContacts)
        }
    }

    private func load() {
        let defaults = UserDefaults.standard

        isArmed = defaults.bool(forKey: Key.armed)
        currentIndex = defaults.integer(forKey: Key.index)
        minSeconds = min(max(defaults.object(forKey: Key.minSeconds) as? Double ?? 14, 0), 60)
        searchTrickArmed = defaults.bool(forKey: Key.searchArmed)
        searchTriggerDigits = min(max(defaults.object(forKey: Key.triggerDigits) as? Int ?? 4, 1), 8)
        lastOpenedName = defaults.string(forKey: Key.lastName) ?? ""
        lastOpenedPhone = defaults.string(forKey: Key.lastPhone) ?? ""
        peekEnabled = defaults.object(forKey: Key.peekEnabled) as? Bool ?? true
        peekSoundEnabled = defaults.object(forKey: Key.peekSound) as? Bool ?? true
        peekHapticEnabled = defaults.object(forKey: Key.peekHaptic) as? Bool ?? true

        if let data = defaults.data(forKey: Key.profiles),
           let decoded = try? JSONDecoder().decode([TrickProfile].self, from: data) {
            profiles = decoded
        }
        if let data = defaults.data(forKey: Key.forcedContacts),
           let decoded = try? JSONDecoder().decode([ForcedContact].self, from: data) {
            forcedContacts = decoded
        }

        isLoaded = true
        sanitizeSequence()
    }
}

// MARK: - Birthday input

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
