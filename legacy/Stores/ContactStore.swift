import Combine
import Contacts
import Foundation

// MARK: - Access state

enum ContactAccessState: Equatable {
    case notDetermined
    case requesting
    case authorized
    case limited
    case denied
    case restricted

    var canRead: Bool {
        self == .authorized || self == .limited
    }
}

// MARK: - Contact store

@MainActor
final class ContactStore: ObservableObject {
    @Published private(set) var contacts: [Contact] = []
    @Published private(set) var groups: [ContactGroup] = []
    @Published private(set) var accessState: ContactAccessState = .notDetermined
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var selectedGroupID: String?

    private let store = CNContactStore()
    private var fetchGeneration = 0
    private var hasLoadedOnce = false

    init() {
        accessState = Self.currentAccessState()
        NotificationCenter.default.addObserver(
            forName: .CNContactStoreDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh(force: true)
            }
        }
    }

    // MARK: Lifecycle

    func prepare() async {
        if accessState == .notDetermined {
            await requestAccess()
        }

        guard accessState.canRead else { return }
        if !hasLoadedOnce {
            refresh(force: true)
        }
    }

    func refreshForForeground() {
        let status = Self.currentAccessState()
        if accessState != status {
            accessState = status
        }

        if status.canRead {
            refresh(force: true)
        } else {
            contacts = []
            groups = []
            hasLoadedOnce = false
        }
    }

    func retry() {
        if accessState.canRead {
            refresh(force: true)
        } else {
            Task { await prepare() }
        }
    }

    func selectGroup(_ groupID: String?) {
        guard selectedGroupID != groupID else { return }
        selectedGroupID = groupID
        contacts = []
        refresh(force: true)
    }

    func refresh(force: Bool) {
        guard accessState.canRead else { return }
        guard force || !isLoading else { return }

        fetchGeneration += 1
        let generation = fetchGeneration
        let groupID = selectedGroupID
        isLoading = true
        errorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let contacts = try Self.fetchContacts(groupID: groupID)
                let groups = try Self.fetchGroups()

                DispatchQueue.main.async {
                    guard generation == self.fetchGeneration else { return }
                    self.contacts = contacts
                    self.groups = groups
                    self.isLoading = false
                    self.hasLoadedOnce = true

                    if let groupID = self.selectedGroupID,
                       !groups.contains(where: { $0.id == groupID }) {
                        self.selectedGroupID = nil
                        self.refresh(force: true)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    guard generation == self.fetchGeneration else { return }
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: Permission

    private func requestAccess() async {
        accessState = .requesting

        await withCheckedContinuation { continuation in
            store.requestAccess(for: .contacts) { _, _ in
                continuation.resume()
            }
        }

        accessState = Self.currentAccessState()
    }

    private static func currentAccessState() -> ContactAccessState {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .notDetermined:
            return .notDetermined
        case .authorized:
            return .authorized
        case .limited:
            return .limited
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .denied
        }
    }

    // MARK: Fetching

    private static var fetchKeys: [CNKeyDescriptor] {
        [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactBirthdayKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor,
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
        ]
    }

    private static func fetchContacts(groupID: String?) throws -> [Contact] {
        let contactStore = CNContactStore()
        let request = CNContactFetchRequest(keysToFetch: fetchKeys)
        request.unifyResults = true
        request.sortOrder = .userDefault

        if let groupID {
            request.predicate = CNContact.predicateForContactsInGroup(withIdentifier: groupID)
        }

        var result: [Contact] = []
        try contactStore.enumerateContacts(with: request) { cnContact, _ in
            result.append(makeContact(from: cnContact))
        }

        return result.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private static func fetchGroups() throws -> [ContactGroup] {
        let contactStore = CNContactStore()
        let groups = try contactStore.groups(matching: nil)
        return groups
            .map { ContactGroup(id: $0.identifier, name: $0.name) }
            .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
    }

    private static func makeContact(from cnContact: CNContact) -> Contact {
        let formattedName = CNContactFormatter
            .string(from: cnContact, style: .fullName)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let fallbackName = [
            cnContact.organizationName,
            cnContact.phoneNumbers.first?.value.stringValue,
            cnContact.emailAddresses.first?.value as String?
        ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })

        let name = (formattedName?.isEmpty == false ? formattedName : nil)
            ?? fallbackName
            ?? NSLocalizedString("No Name", comment: "Unnamed contact")

        let phones = cnContact.phoneNumbers.map { item in
            ContactField(
                label: ContactLabel.localized(item.label),
                value: item.value.stringValue
            )
        }

        let emails = cnContact.emailAddresses.map { item in
            ContactField(
                label: ContactLabel.localized(item.label),
                value: item.value as String
            )
        }

        return Contact(
            id: cnContact.identifier,
            givenName: cnContact.givenName,
            familyName: cnContact.familyName,
            organizationName: cnContact.organizationName,
            name: name,
            phoneNumbers: phones,
            emailAddresses: emails,
            birthday: cnContact.birthday,
            imageData: cnContact.thumbnailImageData
        )
    }
}
