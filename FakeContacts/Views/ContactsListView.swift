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
    @State private var peekName = ""
    @State private var peekClearWork: DispatchWorkItem?
    @State private var showConfig = false
    @FocusState private var searchFocused: Bool

    var searchDigits: String {
        searchText.filter { $0.isNumber }
    }

    // MARK: - Contacts matching
    var filteredContacts: [Contact] {
        matchingContacts(for: searchText)
    }

    private func matchingContacts(for text: String) -> [Contact] {
        guard !text.isEmpty else { return store.contacts }

        let digits = text.filter { $0.isNumber }
        let trigger = trickEngine.searchTriggerDigits
        let isPureDigits = !digits.isEmpty && text.allSatisfy { $0.isNumber }

        let real = store.contacts.filter { contact in
            contact.name.localizedCaseInsensitiveContains(text) ||
            (!digits.isEmpty && contact.phone.filter({ $0.isNumber }).contains(digits))
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
                // Fond plein écran séparé du contenu : la barre de navigation
                // est transparente et rien ne peut être coupé en haut.
                Color.black
                    .ignoresSafeArea()

                List {
                    ForEach(grouped, id: \.0) { letter, contacts in
                        Section {
                            ForEach(contacts) { contact in
                                NavigationLink(destination:
                                    ContactDetailView(
                                        contact: contact,
                                        fromSearch: !searchText.isEmpty,
                                        searchPrefix: searchDigits
                                    )
                                    .environmentObject(trickEngine)
                                ) {
                                    HStack(spacing: 12) {
                                        AvatarView(contact: contact, size: 36)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(contact.name)
                                                .font(.system(size: 17))
                                                .foregroundStyle(.white)

                                            // Pendant une recherche, on montre le
                                            // numéro : pour les contacts forcés, il
                                            // commence par les chiffres tapés.
                                            if !searchText.isEmpty && !contact.phone.isEmpty {
                                                Text(formatPhone(contact.phone))
                                                    .font(.system(size: 15))
                                                    .foregroundStyle(Color.white.opacity(0.5))
                                            }
                                        }
                                    }
                                    // Toute la largeur de la bande est cliquable.
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                                .simultaneousGesture(TapGesture().onEnded {
                                    endSearchInteraction()
                                })
                            }
                        } header: {
                            Text(letter)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.55))
                                .textCase(nil)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.immediately)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    searchBar
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Contacts")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
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
                        .contentShape(Rectangle())
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
            .onChange(of: searchText) { _, newValue in
                // L'utilisateur reprend la main : le nom du peek disparaît.
                if !newValue.isEmpty {
                    peekClearWork?.cancel()
                    peekName = ""
                }
            }
            .onDisappear { searchFocused = false }
        }
        .background {
            // MPVolumeView invisible mais bien dans la hiérarchie : c'est lui
            // qui garantit un changement de volume à chaque appui.
            SystemVolumeView()
                .frame(width: 8, height: 8)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Search bar (flottante, margée comme Contacts)
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.55))

            TextField(
                "",
                text: $searchText,
                prompt: Text(peekName.isEmpty ? "Search" : peekName)
                    .foregroundColor(peekName.isEmpty ? Color.white.opacity(0.5) : .white)
            )
            .font(.system(size: 17))
            .foregroundStyle(.white)
            .tint(.blue)
            .autocorrectionDisabled()
            .submitLabel(.search)
            .focused($searchFocused)
            .onSubmit { searchFocused = false }

            if searchText.isEmpty {
                Image(systemName: "mic.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.white.opacity(0.55))
            } else {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(Color.white.opacity(0.45))
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 46)
        .background(Capsule().fill(Color(white: 0.13)))
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(Color.black)
    }

    // MARK: - Peek
    // Discret : le nom du dernier contact ouvert s'affiche simplement dans la
    // barre de recherche, sans toucher à la recherche ni filtrer la liste.
    private func performPeek() {
        let name = trickEngine.lastOpenedName
        guard !name.isEmpty else {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
            return
        }

        trickEngine.triggerPeekFeedback()

        peekClearWork?.cancel()
        peekName = name

        let work = DispatchWorkItem {
            if peekName == name { peekName = "" }
        }
        peekClearWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
    }

    // Quitte la recherche (clavier + nom du peek) sans effacer le texte tapé,
    // pour retrouver exactement la même liste en revenant du contact.
    private func endSearchInteraction() {
        searchFocused = false
        peekClearWork?.cancel()
        peekClearWork = nil
        peekName = ""
    }
}
