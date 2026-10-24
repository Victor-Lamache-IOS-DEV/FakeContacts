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
class VolumeObserver: NSObject, ObservableObject {
    private let audioSession = AVAudioSession.sharedInstance()
    private var debounceTimer: Timer?
    var onVolumeDown: (() -> Void)?

    override init() {
        super.init()
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
        guard newVol < oldVol else { return }
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.onVolumeDown?()
                resetVolumeToMid()
            }
        }
    }

    deinit { audioSession.removeObserver(self, forKeyPath: "outputVolume") }
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
    @State private var plusTapCount = 0
    @State private var titleTapCount = 0
    @State private var plusTapTimer: Timer? = nil
    @State private var titleTapTimer: Timer? = nil

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
                Section {
                    Text("Contacts")
                        .font(.system(size: 34, weight: .bold))
                        .padding(.vertical, 4)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .onTapGesture {
                            titleTapCount += 1
                            titleTapTimer?.invalidate()
                            titleTapTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                                if titleTapCount >= 3 { showConfig = true }
                                titleTapCount = 0
                            }
                        }
                }

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
                                Text(contact.name)
                                    .font(.system(size: 17, weight: .medium))
                                    .padding(.vertical, 2)
                            }
                        }
                    } header: {
                        Text(letter)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .id(listID)
            .listStyle(.plain)
            .searchable(text: $searchText, prompt: "Search")
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Image(systemName: "plus")
                        .foregroundColor(trickEngine.isArmed ? .white : .blue)
                        .onTapGesture {
                            plusTapCount += 1
                            plusTapTimer?.invalidate()
                            plusTapTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { _ in
                                if plusTapCount >= 2 {
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                    
                                    if trickEngine.isArmed { trickEngine.disarm() }
                                    else { trickEngine.arm() }
                                }
                                plusTapCount = 0
                            }
                        }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Lists") {}
                        .foregroundColor(.blue)
                }
            }
            .sheet(isPresented: $showConfig) {
                ConfigView().environmentObject(trickEngine)
            }
            .onAppear {
                store.requestAndLoad()
                resetVolumeToMid()
                volumeObserver.onVolumeDown = {
                    guard !trickEngine.lastOpenedName.isEmpty else { return }
                    let last4 = String(trickEngine.lastOpenedPhone.suffix(4))
                    searchText = ""
                    listID = UUID()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                        
                        isFlashing = true
                        searchText = "\(trickEngine.lastOpenedName)  ···\(last4)"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            searchText = ""
                            isFlashing = false
                        }
                    }
                }
            }
            .overlay {
                if store.permissionDenied {
                    if #available(iOS 17.0, *) {
                        ContentUnavailableView(
                            "No Access to Contacts",
                            systemImage: "person.crop.circle.badge.exclamationmark",
                            description: Text("Allow access in Settings → Privacy → Contacts")
                        )
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.badge.exclamationmark")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("No Access to Contacts")
                                .font(.headline)
                            Text("Allow access in Settings → Privacy → Contacts")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
}
