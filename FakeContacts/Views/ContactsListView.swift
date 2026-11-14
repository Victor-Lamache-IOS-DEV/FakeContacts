import SwiftUI
import AVFoundation
import MediaPlayer
import UIKit
import QuartzCore

// MARK: - VolumeController
final class VolumeController {
    static let shared = VolumeController()
    weak var slider: UISlider?
    private var fallbackView: MPVolumeView?

    func attach(_ slider: UISlider) { self.slider = slider }

    func ensureAttached() {
        if slider == nil { ensureSlider() }
    }

    private func ensureSlider() {
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

    func reset() {
        ensureAttached()
        guard let slider = slider else { return }
        if abs(slider.value - 0.5) > 0.001 { slider.value = 0.5 }
    }

    func set(_ value: Float) {
        ensureAttached()
        guard let slider = slider else { return }
        if abs(slider.value - value) > 0.001 { slider.value = value }
    }
}

// MARK: - SystemVolumeView
struct SystemVolumeView: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: CGRect(x: 0, y: 0, width: 8, height: 8))
        view.showsRouteButton = false
        view.alpha = 0.02
        view.clipsToBounds = false
        return view
    }
    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}

// MARK: - VolumeObserver
class VolumeObserver: NSObject, ObservableObject {
    private let audioSession = AVAudioSession.sharedInstance()
    private var debounce: DispatchWorkItem?
    private var boundaryTimer: Timer?
    private var ignoreUntil: CFTimeInterval = CACurrentMediaTime() + 1.0
    var onVolumePress: (() -> Void)?

    override init() {
        super.init()
        SilentAudioPlayer.shared.start()
        try? audioSession.setActive(true)
        audioSession.addObserver(self, forKeyPath: "outputVolume",
                                  options: [.new, .old], context: nil)
        boundaryTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.nudgeAwayFromBounds()
        }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                                change: [NSKeyValueChangeKey: Any]?,
                                context: UnsafeMutableRawPointer?) {
        guard keyPath == "outputVolume" else { return }
        guard CACurrentMediaTime() >= ignoreUntil else { return }
        debounce?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.ignoreUntil = CACurrentMediaTime() + 0.6
            VolumeController.shared.reset()
            self?.onVolumePress?()
        }
        debounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }

    private func nudgeAwayFromBounds() {
        VolumeController.shared.ensureAttached()
        guard let slider = VolumeController.shared.slider else { return }
        if slider.value <= 0.001 {
            ignoreUntil = CACurrentMediaTime() + 0.5
            VolumeController.shared.set(0.25)
        } else if slider.value >= 0.999 {
            ignoreUntil = CACurrentMediaTime() + 0.5
            VolumeController.shared.set(0.75)
        }
    }

    deinit {
        debounce?.cancel()
        boundaryTimer?.invalidate()
        audioSession.removeObserver(self, forKeyPath: "outputVolume")
    }
}

// MARK: - AvatarView
struct AvatarView: View {
    let contact: Contact
    let size: CGFloat

    var body: some View {
        if let img = contact.thumbnailImage {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            ZStack {
                Circle().fill(
                    LinearGradient(colors: [Color(hex: "6A5C78"), Color(hex: "493D55")],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                Circle().strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                Text(initials)
                    .font(.system(size: size * 0.46, weight: .medium))
                    .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
        }
    }

    var initials: String {
        contact.name.split(separator: " ").prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined()
    }
}

// MARK: - ActionBtn
struct ActionBtn: View {
    let icon: String
    var dimmed: Bool = false

    var body: some View {
        Circle()
            .fill(Color.black.opacity(0.55))
            .frame(width: 56, height: 56)
            .overlay(
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(dimmed ? Color.white.opacity(0.35) : .white)
            )
    }
}

// MARK: - DataCard
struct DataCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, 14)
            .background(Color.black.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - BottomRow
struct BottomRow: View {
    let label: String

    var body: some View {
        Button(action: {}) {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
        }
    }
}

// MARK: - ContactListRow
struct ContactListRow: View {
    let contact: Contact
    @Binding var searchText: String
    let formatPhone: (String) -> String

    var body: some View {
        HStack(spacing: 10) {
            AvatarView(contact: contact, size: 40)

            VStack(alignment: .leading, spacing: 1) {
                Text(contact.name)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)

                if !searchText.isEmpty && !contact.phone.isEmpty {
                    Text(formatPhone(contact.phone))
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

// MARK: - ContactsListView
struct ContactsListView: View {
    @EnvironmentObject var trickEngine: TrickEngine
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = ContactStore()
    @StateObject private var volumeObserver = VolumeObserver()
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool

    var searchDigits: String { searchText.filter { $0.isNumber } }

    // MARK: - Corps de la liste
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                List {
                    ForEach(grouped, id: \.0) { letter, contacts in
                        Section {
                            ForEach(contacts) { contact in
                                ContactListRow(contact: contact, searchText: $searchText,
                                               formatPhone: formatPhone)
                                    .listRowInsets(EdgeInsets(top: 1, leading: 12, bottom: 1, trailing: 12))
                            }
                        } header: {
                            Text(letter)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.55))
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.immediately)
                .safeAreaInset(edge: .bottom, spacing: 0) { searchBar }
                .overlay { permissionDeniedView }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Contacts")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .onTapGesture(count: 3) { /* config */}
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Lists") {}
                }
            }
            .onAppear {
                store.requestAndLoad()
                SilentAudioPlayer.shared.start()
                VolumeController.shared.reset()
                volumeObserver.onVolumePress = performPeek
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    SilentAudioPlayer.shared.start()
                    VolumeController.shared.reset()
                }
            }
        }
        .background {
            SystemVolumeView()
                .frame(width: 8, height: 8)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Barre de recherche en bas
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.55))

            TextField("", text: $searchText, prompt: Text("Search")
                    .foregroundColor(Color.white.opacity(0.5)))
                .font(.system(size: 17))
                .foregroundStyle(.white)
                .tint(.blue)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($searchFocused)
                .onSubmit { searchFocused = false }

            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.white.opacity(0.45))
                }
            }

            Image(systemName: searchText.isEmpty ? "mic.fill" : "")
                .font(.system(size: 15))
                .foregroundStyle(Color.white.opacity(0.55))
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(Capsule().fill(Color(white: 0.13)))
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Color.black)
    }

    private var permissionDeniedView: some View {
        ContentUnavailableView("No Access to Contacts",
            systemImage: "person.crop.circle.badge.exclamationmark",
            description: Text("Allow access in Settings → Privacy → Contacts"))
    }

    // MARK: - Groupe par lettre
    var grouped: [(String, [Contact])] {
        var dict: [String: [Contact]] = [:]
        for contact in store.contacts {
            let first = String(contact.name.prefix(1)).uppercased()
            let key = first.first?.isLetter == true ? first : "#"
            dict[key, default: []].append(contact)
        }
        return dict.sorted { $0.key < $1.key }
    }

    // MARK: - Peek (volume button)
    private func performPeek() {
        let name = trickEngine.lastOpenedName
        guard !name.isEmpty else {
            let gen = UINotificationFeedbackGenerator(); gen.notificationOccurred(.warning); return
        }
        trickEngine.triggerPeekFeedback()
        // Affiche le nom dans la barre de recherche pendant 3 s, sans filtrer.
        searchText = name
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if searchText == name { searchText = "" }
        }
    }
}