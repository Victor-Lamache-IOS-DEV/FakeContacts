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
// Observes AVAudioSession.outputVolume. Thanks to SilentAudioPlayer keeping a
// silent playback session active, the hardware volume buttons now control the
// *media* volume even when the Ring/Silent switch is on silent.
//
// We detect ANY significant volume change (up OR down), so a single press is
// enough to trigger the peek regardless of the current volume level (even at 0
// or max). After triggering, volume is reset to mid so the next press works too.
class VolumeObserver: NSObject, ObservableObject {
    private let audioSession = AVAudioSession.sharedInstance()
    private var debounceTimer: Timer?
    var onVolumePress: (() -> Void)?

    override init() {
        super.init()
        SilentAudioPlayer.shared.start() // force media-volume control
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
            ZStack {
                // iOS 26 glass background
                if #available(iOS 26.0, *) {
                    Color(.systemGroupedBackground)
                        .glassEffect()
                        .ignoresSafeArea()
                } else {
                    Color(.systemBackground)
                        .ignoresSafeArea()
                }

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
                                    HStack(spacing: 12) {
                                        AvatarView(contact: contact, size: 44)
                                            .shimmer(trickEngine.isArmed)
                                        Text(contact.name)
                                            .font(.system(size: 17, weight: .medium))
                                            .foregroundColor(.primary)
                                            .padding(.vertical, 2)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .glassRow(isArmed: trickEngine.isArmed)
                            }
                        } header: {
                            Text(letter)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                                .padding(.top, 2)
                        }
                    }
                }
                .id(listID)
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .searchable(text: $searchText, prompt: "Search")
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 14) {
                            // Peek button — reliable fallback for the volume trick
                            GlassToolbarButton(icon: "waveform.circle.fill") {
                                performPeek()
                            }
                            .tint(.blue)
                            .accessibilityLabel("Peek last opened contact")

                            // Arm / disarm trick 1 (double-tap plus)
                            Image(systemName: "plus")
                                .foregroundColor(trickEngine.isArmed ? .white : .blue)
                                .armedPulse(trickEngine.isArmed)
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
                    volumeObserver.onVolumePress = {
                        performPeek()
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

    // MARK: - Peek
    private func performPeek() {
        guard !trickEngine.lastOpenedName.isEmpty else {
            // Nothing to peek yet — gentle haptic
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
            return
        }

        let last4 = String(trickEngine.lastOpenedPhone.suffix(4))

        // Feedback (sound + haptic) according to user settings
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

// MARK: - View modifiers (glass row)
extension View {
    func glassRow(isArmed: Bool) -> some View {
        self
            .listRowBackground(
                Group {
                    if #available(iOS 26.0, *) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .glassEffect()
                            .tint(isArmed ? .red.opacity(0.12) : .white.opacity(0.05))
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(isArmed ? 0.09 : 0.05))
                    }
                }
            )
            .listRowSeparator(.hidden)
            .padding(.vertical, 5)
            .padding(.horizontal, 2)
    }
}
