import SwiftUI
import AVFoundation
import MediaPlayer

// MARK: - Volume helpers
private func resetVolumeToMid() {
    DispatchQueue.main.async {
        let volumeView = MPVolumeView()
        if let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
            slider.value = 0.5
        }
    }
}

// MARK: - Volume Observer
//
// Détecte n'importe quel appui sur les boutons volume (haut ou bas) pour
// déclencher le "peek". Une seule pression suffit, quel que soit le niveau
// de volume actuel (même à 0 ou au maximum).
class VolumeObserver: NSObject, ObservableObject {
    private let audioSession = AVAudioSession.sharedInstance()
    private var debounceTimer: Timer?
    var onVolumePress: (() -> Void)?

    override init() {
        super.init()
        SilentAudioPlayer.shared.start() // force le contrôle volume media même en silencieux
        try? audioSession.setActive(true)
        audioSession.addObserver(self, forKeyPath: "outputVolume",
                                  options: [.new, .old], context: nil)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                                change: [NSKeyValueChangeKey: Any]?,
                                context: UnsafeMutableRawPointer?) {
        guard keyPath == "outputVolume" else { return }
        let newVol = (change?[.newKey] as? Float) ?? 0
        let oldVol = (change?[.oldKey] as? Float) ?? 0
        guard abs(newVol - oldVol) > 0.05 else { return }
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.onVolumePress?()
                resetVolumeToMid()
            }
        }
    }

    deinit {
        SilentAudioPlayer.shared.stop()
        audioSession.removeObserver(self, forKeyPath: "outputVolume")
    }
}

// MARK: - Contacts List View
struct ContactsListView: View {
    @EnvironmentObject var trickEngine: TrickEngine
    @StateObject private var store = ContactStore()
    @StateObject private var volumeObserver = VolumeObserver()
    @State private var searchText = ""
    @State private var isFlashing = false
    @State private var showConfig = false
    @State private var listID = UUID()

    var searchDigits: String {
        searchText.filter { $0.isNumber }
    }

    var filteredContacts: [Contact] {
        if isFlashing { return store.contacts }

        let digits = searchDigits
        let trigger = trickEngine.searchTriggerDigits
        let isPureDigits = !searchText.isEmpty && searchText.allSatisfy { $0.isNumber }

        if searchText.isEmpty { return store.contacts }

        let real = store.contacts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.phone.filter({ $0.isNumber }).contains(digits)
        }

        guard trickEngine.searchTrickArmed && isPureDigits else { return real }

        if digits.count == trigger {
            return trickEngine.forcedContacts.map { fc in
                Contact(name: fc.fakeName, phone: digits + fc.phoneSuffix,
                        note: fc.fakeNote, thumbnailImage: nil,
                        forcedSuffix: fc.phoneSuffix, forcedSearchNote: fc.fakeNote,
                        forcedEmail: fc.fakeEmail.isEmpty ? nil : fc.fakeEmail,
                        forcedBirthday: fc.fakeBirthday.isEmpty ? nil : fc.fakeBirthday)
            }.shuffled()
        }

        if digits.count > trigger { return [] }

        let fakes = trickEngine.forcedContacts.map { fc in
            Contact(name: fc.fakeName, phone: digits + fc.phoneSuffix,
                    note: fc.fakeNote, thumbnailImage: nil,
                    forcedSuffix: fc.phoneSuffix, forcedSearchNote: fc.fakeNote,
                    forcedEmail: fc.fakeEmail.isEmpty ? nil : fc.fakeEmail,
                    forcedBirthday: fc.fakeBirthday.isEmpty ? nil : fc.fakeBirthday)
        }
        return (real + fakes).shuffled()
    }

    var grouped: [(String, [Contact])] {
        var dict: [String: [Contact]] = [:]
        for contact in filteredContacts {
            let first = String(contact.name.prefix(1)).uppercased()
            let key = first.first?.isLetter == true ? first : "#"
            dict[key, default: []].append(contact)
        }
        return dict.sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(grouped, id: \.0) { letter, contacts in
                    Section {
                        ForEach(contacts) { contact in
                            NavigationLink(destination:
                                ContactDetailView(
                                    contact: contact,
                                    fromSearch: !searchText.isEmpty && !isFlashing,
                                    searchPrefix: searchDigits
                                )
                                .environmentObject(trickEngine)
                            ) {
                                HStack(spacing: 12) {
                                    AvatarView(contact: contact, size: 50)
                                    Text(contact.name)
                                        .font(.system(size: 17))
                                        .foregroundStyle(.primary)
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                        }
                    } header: {
                        Text(letter)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .id(listID)
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .searchable(text: $searchText, prompt: "Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Contacts")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                        .onTapGesture(count: 3) { showConfig = true }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Lists") {}
                }
                ToolbarItem(placement: .topBarTrailing) {
                    // Double-tap : arme / désarme le trick 1
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(trickEngine.isArmed ? Color.red : Color.blue)
                        .onTapGesture(count: 2) {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            if trickEngine.isArmed { trickEngine.disarm() }
                            else { trickEngine.arm() }
                        }
                }
            }
            .sheet(isPresented: $showConfig) {
                ConfigView().environmentObject(trickEngine)
            }
            .onAppear {
                store.requestAndLoad()
                resetVolumeToMid()
                volumeObserver.onVolumePress = {
                    performPeek()
                }
            }
            .overlay {
                if store.permissionDenied {
                    ContentUnavailableView(
                        "No Access to Contacts",
                        systemImage: "person.crop.circle.badge.exclamationmark",
                        description: Text("Allow access in Settings → Privacy → Contacts")
                    )
                }
            }
        }
    }

    // MARK: - Peek
    private func performPeek() {
        guard !trickEngine.lastOpenedName.isEmpty else {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
            return
        }

        let last4 = String(trickEngine.lastOpenedPhone.suffix(4))

        trickEngine.triggerPeekFeedback()

        searchText = ""
        listID = UUID()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isFlashing = true
            searchText = "\(trickEngine.lastOpenedName)  ···\(last4)"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                searchText = ""
                isFlashing = false
            }
        }
    }
}
