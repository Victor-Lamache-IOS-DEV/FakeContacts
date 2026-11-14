import SwiftUI
import UIKit
import CoreImage

// MARK: - Hex Color
extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        self.init(
            red:   Double((int >> 16) & 0xFF) / 255,
            green: Double((int >> 8)  & 0xFF) / 255,
            blue:  Double(int         & 0xFF) / 255
        )
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

// MARK: - ContactDetailView
struct ContactDetailView: View {
    let contact: Contact
    let fromSearch: Bool
    let searchPrefix: String

    @EnvironmentObject var trickEngine: TrickEngine
    @Environment(\.dismiss) var dismiss

    @State private var snapshotPhone: String    = ""
    @State private var snapshotNote: String     = ""
    @State private var snapshotEmail: String    = ""
    @State private var snapshotBirthday: String = ""
    @State private var timeOnPage: Double       = 0
    @State private var ticker: Timer?           = nil
    @State private var hasAdvanced              = false

    // Fond uni (photo) ou dégradé (pas de photo)
    @State private var photoBackground: Color = Color(hex: "5B6870")

    init(contact: Contact, fromSearch: Bool = false, searchPrefix: String = "") {
        self.contact = contact
        self.fromSearch = fromSearch
        self.searchPrefix = searchPrefix
    }

    var body: some View {
        ZStack {
            // Fond plein écran, totalement séparé du ScrollView.
            // Passe derrière la barre d'état et la barre de navigation,
            // donc le haut ne peut jamais être coupé.
            Color.black
                .ignoresSafeArea(edges: .all)

            Color.black
                .ignoresSafeArea(edges: .all)

            ScrollView {
                VStack(spacing: 0) {

                    // --- Avatar grand ---
                    AvatarView(contact: contact, size: 200)
                        .padding(.top, 24)
                        .padding(.bottom, 22)

                    // --- Nom ---
                    Text(contact.name)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)

                    // --- Boutons d'action ---
                    HStack(spacing: 12) {
                        ActionBtn(icon: "message.fill")
                        ActionBtn(icon: "phone.fill")
                        ActionBtn(icon: "video.fill")
                        ActionBtn(icon: "envelope.fill", dimmed: true)
                    }
                    .padding(.bottom, 24)

                    // --- Infos (téléphone + notes) ---
                    DataCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("phone")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.white.opacity(0.55))
                            Text(snapshotPhone)
                                .font(.system(size: 17))
                                .foregroundStyle(.white)
                            if !snapshotNote.isEmpty {
                                Text("Notes")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.white.opacity(0.55))
                                Text(snapshotNote)
                                    .font(.system(size: 17))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 70, alignment: .topLeading)
                        .padding(.vertical, 10)
                    }

                    // --- Email ---
                    if !snapshotEmail.isEmpty {
                        DataCard {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("email")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.white.opacity(0.55))
                                Text(snapshotEmail)
                                    .font(.system(size: 17))
                                    .foregroundStyle(.white)
                            }
                            .padding(.vertical, 8)
                        }
                    }

                    // --- Anniversaire ---
                    if !snapshotBirthday.isEmpty {
                        DataCard {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("birthday")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.white.opacity(0.55))
                                Text(snapshotBirthday)
                                    .font(.system(size: 17))
                                    .foregroundStyle(.white)
                            }
                            .padding(.vertical, 6)
                        }
                    }

                    // --- Actions du bas ---
                    VStack(spacing: 0) {
                        BottomRow(label: "Send Message")
                        Divider().background(Color(.systemGray5))
                        BottomRow(label: "Share Contact")
                        Divider().background(Color(.systemGray5))
                        BottomRow(label: "Add to Favourites")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)

                    Spacer().frame(height: 24)
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background { Circle().fill(Color.black) }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Text("Edit")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background { Capsule().fill(Color.black) }
            }
        }
        .onAppear {
            // Refermer le clavier si on vient de la recherche
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )

            // Pré-remplir les infos
            if fromSearch && contact.forcedSuffix != nil {
                let rawPhone = searchPrefix + (contact.forcedSuffix ?? "")
                snapshotPhone = formatPhone(rawPhone)
                snapshotNote  = contact.forcedSearchNote ?? ""
                snapshotEmail = contact.forcedEmail ?? ""
                snapshotBirthday = contact.forcedBirthday ?? ""
            } else {
                let profile = trickEngine.currentProfile()
                snapshotPhone    = formatPhone(profile?.fakePhone.isEmpty == false ? profile!.fakePhone : contact.phone)
                snapshotNote     = profile?.fakeNote.isEmpty == false ? profile!.fakeNote : contact.note
                snapshotEmail    = profile?.fakeEmail.isEmpty == false ? profile!.fakeEmail : contact.email
                snapshotBirthday = profile?.fakeBirthday.isEmpty == false ? profile!.fakeBirthday : contact.birthday
            }
            // Persisté pour le peek
            trickEngine.markLastOpened(contact, phone: snapshotPhone)

            // Couleur de fond dérivée de la photo
            if let img = contact.thumbnailImage,
               let muted = img.mutedBackgroundColor {
                photoBackground = muted
            }
        }
        .onDisappear { stopTimer() }
    }

    // MARK: - Minuteur
    private func startTimer() {
        timeOnPage = 0; hasAdvanced = false
        if trickEngine.minSeconds == 0 {
            hasAdvanced = true; trickEngine.advance(); return
        }
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            timeOnPage += 1
            if timeOnPage >= trickEngine.minSeconds && !hasAdvanced {
                hasAdvanced = true; trickEngine.advance(); ticker?.invalidate()
            }
        }
    }
    private func stopTimer() { ticker?.invalidate(); ticker = nil }
}

// MARK: - ActionBtn (cercle)
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