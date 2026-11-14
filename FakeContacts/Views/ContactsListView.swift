import SwiftUI
import AVFoundation
import MediaPlayer
import UIKit
import QuartzCore

// MARK: - Hidden system volume slider
//
// Un MPVolumeView réellement présent dans la hiérarchie de vues est le seul
// moyen fiable de piloter le volume système. On le garde hors écran et on
// remet le volume au milieu après chaque appui : ainsi un appui fonctionne
// toujours, que le volume soit à 0, au maximum ou au milieu.
final class VolumeController {
    static let shared = VolumeController()
    weak var slider: UISlider?
    private var fallbackView: MPVolumeView?

    func attach(_ slider: UISlider) {
        self.slider = slider
    }

    func ensureAttached() {
        if slider == nil { ensureSlider() }
    }

    func reset() {
        ensureAttached()
        guard let slider = slider else { return }
        if abs(slider.value - 0.5) > 0.001 {
            slider.value = 0.5
        }
    }

    func set(_ value: Float) {
        ensureAttached()
        guard let slider = slider else { return }
        if abs(slider.value - value) > 0.001 {
            slider.value = value
        }
    }

    func nudgeFromBounds() {
        ensureAttached()
        guard let slider = slider else { return }
        if slider.value <= 0.001 {
            slider.value = 0.25
        } else if slider.value >= 0.999 {
            slider.value = 0.75
        }
    }

    // Filet de sécurité : si la vue SwiftUI n'a pas encore exposé son slider,
    // on ajoute un MPVolumeView hors écran directement dans la fenêtre.
    private func ensureSlider() {
        if let fallbackView = fallbackView,
           let existing = fallbackView.subviews.compactMap({ $0 as? UISlider }).first {
            slider = existing
            return
        }
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) else { return }

        let view = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 10, height: 10))
        view.showsRouteButton = false
        window.addSubview(view)
        fallbackView = view

        if let existing = view.subviews.compactMap({ $0 as? UISlider }).first {
            slider = existing
        }
    }
}

struct SystemVolumeView: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: CGRect(x: 0, y: 0, width: 8, height: 8))
        view.showsRouteButton = false
        view.alpha = 0.02
        view.clipsToBounds = false
        attachSlider(from: view)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { attachSlider(from: view) }
        return view
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {
        attachSlider(from: uiView)
    }

    private func attachSlider(from view: MPVolumeView) {
        if let slider = view.subviews.compactMap({ $0 as? UISlider }).first {
            VolumeController.shared.attach(slider)
        }
    }
}

// MARK: - Volume Observer
//
// Déclenche le "peek" sur N'IMPORTE QUEL appui volume (haut ou bas), une
// seule pression suffit, quel que soit le niveau de volume.
class VolumeObserver: NSObject, ObservableObject {
    private let audioSession = AVAudioSession.sharedInstance()
    private var debounce: DispatchWorkItem?
    private var boundaryTimer: Timer?
    private var ignoreUntil: CFTimeInterval = CACurrentMediaTime() + 1.0
    var onVolumePress: (() -> Void)?

    override init() {
        super.init()
        SilentAudioPlayer.shared.start() // boutons volume = volume média, même en silencieux
        try? audioSession.setActive(true)
        audioSession.addObserver(self, forKeyPath: "outputVolume",
                                  options: [.new, .old], context: nil)

        // Si le volume traîne à 0 ou au maximum, on le décolle de la borne :
        // ainsi un appui dans n'importe quel sens produit toujours un changement.
        boundaryTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.nudgeAwayFromBounds()
        }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                                change: [NSKeyValueChangeKey: Any]?,
                                context: UnsafeMutableRawPointer?) {
        guard keyPath == "outputVolume" else { return }

        // Ignore les changements provoqués par nos propres réglages.
        guard CACurrentMediaTime() >= ignoreUntil else { return }

        debounce?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.ignoreUntil = CACurrentMediaTime() + 0.6
            VolumeController.shared.reset()
            self.onVolumePress?()
        }
        debounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }

    private func nudgeAwayFromBounds() {
        VolumeController.shared.ensureAttached()
        guard let slider = VolumeController.shared.slider else { return }
        guard slider.value <= 0.001 || slider.value >= 0.999 else { return }
        ignoreUntil = CACurrentMediaTime() + 0.5
        VolumeController.shared.nudgeFromBounds()
    }

    deinit {
        debounce?.cancel()
        boundaryTimer?.invalidate()
        audioSession.removeObserver(self, forKeyPath: "outputVolume")
    }
}

// MARK: - Contacts List View
struct ContactsListView: View {
    @EnvironmentObject var trickEngine: TrickEngine
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = ContactStore()
    @StateObject private var volumeObserver = VolumeObserver()
    @State private var searchText = ""
    @State private var isFlashing = false
    @State private var showConfig = false
    @State private var listID = UUID()

    var searchDigits: String {
        searchText.filter { $0.isNumber }
    }

    // Contact affiché lors du peek (dernier contact ouvert).
    private var peekContact: Contact? {
        let name = trickEngine.lastOpenedName
        guard !name.isEmpty else { return nil }
        if let real = store.contacts.first(where: { $0.name == name }) { return real }
        return Contact(name: name, phone: trickEngine.lastOpenedPhone, note: "")
    }

    var filteredContacts: [Contact] {
        if isFlashing {
            return peekContact.map { [$0] } ?? store.contacts
        }

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
                                    AvatarView(contact: contact, size: 56)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(contact.name)
                                            .font(.system(size: 17))
                                            .foregroundStyle(.primary)
                                        if isFlashing && !contact.phone.isEmpty {
                                            Text(contact.phone)
                                                .font(.system(size: 15))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .padding(.vertical, 6)
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
                    // Double-tap : arme / désarme le trick 1 (blanc = armé, bleu = prêt)
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(trickEngine.isArmed ? Color.white : Color.blue)
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
                SilentAudioPlayer.shared.start()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    VolumeController.shared.reset()
                }
                volumeObserver.onVolumePress = {
                    performPeek()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    SilentAudioPlayer.shared.start()
                    VolumeController.shared.reset()
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
        .background {
            // MPVolumeView invisible mais bien dans la hiérarchie : c'est lui
            // qui garantit un changement de volume à chaque appui.
            SystemVolumeView()
                .frame(width: 8, height: 8)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Peek
    private func performPeek() {
        guard peekContact != nil else {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
            return
        }

        trickEngine.triggerPeekFeedback()

        searchText = ""
        listID = UUID()
        isFlashing = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if isFlashing { isFlashing = false }
        }
    }
}
