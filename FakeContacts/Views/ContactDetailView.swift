import SwiftUI
import UIKit

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

// MARK: - Dominant Color
extension UIImage {
    var dominantColor: Color {
        guard let cgImage = self.cgImage else { return Color(hex: "4f5054") }
        let size = CGSize(width: 40, height: 40)
        let ctx = CGContext(data: nil,
                           width: Int(size.width), height: Int(size.height),
                           bitsPerComponent: 8, bytesPerRow: 0,
                           space: CGColorSpaceCreateDeviceRGB(),
                           bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let c = ctx else { return Color(hex: "4f5054") }
        c.draw(cgImage, in: CGRect(origin: .zero, size: size))
        guard let data = c.data else { return Color(hex: "4f5054") }
        let ptr = data.bindMemory(to: UInt8.self, capacity: Int(size.width * size.height * 4))
        var r: CGFloat = 0; var g: CGFloat = 0; var b: CGFloat = 0
        let count = Int(size.width * size.height)
        for i in 0..<count {
            r += CGFloat(ptr[i*4]); g += CGFloat(ptr[i*4+1]); b += CGFloat(ptr[i*4+2])
        }
        let t = CGFloat(count * 255)
        let rf = r/t, gf = g/t, bf = b/t
        let avg = (rf + gf + bf) / 3
        let boost: CGFloat = 1.6
        let sr = min(1.0, (rf + (rf - avg) * boost) * 0.88)
        let sg = min(1.0, (gf + (gf - avg) * boost) * 0.88)
        let sb = min(1.0, (bf + (bf - avg) * boost) * 0.88)
        return Color(red: sr, green: sg, blue: sb)
    }
}

// MARK: - Avatar View
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
                Circle()
                    .fill(avatarColor)
                    .frame(width: size, height: size)
                Text(initials)
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
    }

    var initials: String {
        contact.name.split(separator: " ").prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined()
    }

    // Couleur stable (pas de hashValue, qui change à chaque lancement).
    private var avatarColor: Color {
        let palette: [Color] = [
            Color(hex: "7A7A8C"), Color(hex: "8E7CC3"), Color(hex: "7C9EC3"),
            Color(hex: "C3877C"), Color(hex: "7CC3A1"), Color(hex: "C3B07C")
        ]
        let sum = contact.name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[sum % palette.count]
    }
}

// MARK: - Contact Detail View
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
    @State private var backgroundColor: Color   = Color(hex: "4f5054")

    init(contact: Contact, fromSearch: Bool = false, searchPrefix: String = "") {
        self.contact = contact
        self.fromSearch = fromSearch
        self.searchPrefix = searchPrefix
    }

    var hasPhoto: Bool { contact.thumbnailImage != nil }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // ── HEADER ──────────────────────────────────
                // Hauteur naturelle : plus de frame fixe, donc plus de
                // contenu rogné ni de bande vide sous les boutons.
                VStack(spacing: 0) {
                    AvatarView(contact: contact, size: hasPhoto ? 250 : 110)
                        .padding(.top, 16)
                        .padding(.bottom, 14)

                    Text(contact.name)
                        .font(.system(size: hasPhoto ? 34 : 28, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                    HStack(spacing: 22) {
                        ActionBtn(icon: "message.fill")
                        ActionBtn(icon: "phone.fill")
                        ActionBtn(icon: "video.fill")
                        ActionBtn(icon: "envelope.fill", dimmed: true)
                    }
                    .padding(.bottom, 26)
                }
                .frame(maxWidth: .infinity)
                .background {
                    // Le fond remonte sous la barre de navigation et la
                    // barre d'état : plus aucune couture visible.
                    headerBackground
                        .ignoresSafeArea(edges: .top)
                }

                // ── DATA ZONE ────────────────────────────────
                VStack(spacing: 10) {

                    DataCard {
                        HStack(spacing: 12) {
                            AvatarView(contact: contact, size: 40)
                            Text("Contact Photo & Poster")
                                .font(.system(size: 17.7))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundColor(Color(.systemGray3))
                        }
                        .padding(.vertical, 10)
                    }

                    // Téléphone + Notes groupés dans une seule carte (comme Contacts)
                    DataCard {
                        VStack(alignment: .leading, spacing: 0) {
                            if !snapshotPhone.isEmpty {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("phone")
                                            .font(.system(size: 13.5))
                                            .foregroundColor(.secondary)
                                        Text(snapshotPhone)
                                            .font(.system(size: 17.7))
                                            .foregroundColor(.blue)
                                    }
                                    Spacer()
                                    Image(systemName: "phone.fill")
                                        .font(.system(size: 17))
                                        .foregroundColor(.blue)
                                }
                                .padding(.vertical, 12)
                                Divider()
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Notes")
                                    .font(.system(size: 13.5))
                                    .foregroundColor(.secondary)
                                if !snapshotNote.isEmpty {
                                    Text(snapshotNote)
                                        .font(.system(size: 17.7))
                                        .foregroundColor(.primary)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 70, alignment: .topLeading)
                            .padding(.vertical, 12)
                        }
                    }

                    if !snapshotEmail.isEmpty {
                        DataCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("email")
                                        .font(.system(size: 13.5))
                                        .foregroundColor(.secondary)
                                    Text(snapshotEmail)
                                        .font(.system(size: 17.7))
                                        .foregroundColor(.blue)
                                }
                                Spacer()
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 17))
                                    .foregroundColor(.blue)
                            }
                            .padding(.vertical, 10)
                        }
                    }

                    if !snapshotBirthday.isEmpty {
                        DataCard {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("birthday")
                                    .font(.system(size: 13.5))
                                    .foregroundColor(.secondary)
                                Text(snapshotBirthday)
                                    .font(.system(size: 17.7))
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                        }
                    }

                    DataCard {
                        VStack(spacing: 0) {
                            BottomRow(label: "Send Message",      color: .blue)
                            Divider().background(Color(.systemGray5))
                            BottomRow(label: "Share Contact",     color: .blue)
                            Divider().background(Color(.systemGray5))
                            BottomRow(label: "Add to Favourites", color: .blue)
                        }
                    }

                    DataCard { BottomRow(label: "Add to Emergency Contacts", color: .blue) }
                    DataCard { BottomRow(label: "Share my Location", color: .blue) }

                    Spacer().frame(height: 40)
                }
                .padding(.top, 14)
                .background(Color.black)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        // Barre transparente : le header passe dessous, sans raccord.
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(Circle().fill(Color.black.opacity(0.25)))
                        }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Text("Edit")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background {
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(Capsule().fill(Color.black.opacity(0.25)))
                    }
            }
        }
        .onAppear {
            if fromSearch && contact.forcedSuffix != nil {
                let rawPhone     = searchPrefix + (contact.forcedSuffix ?? "")
                snapshotPhone    = formatPhone(rawPhone)
                snapshotNote     = contact.forcedSearchNote ?? ""
                snapshotEmail    = contact.forcedEmail ?? ""
                snapshotBirthday = contact.forcedBirthday ?? ""
            } else {
                let profile      = trickEngine.currentProfile()
                let rawPhone     = profile?.fakePhone.isEmpty == false ? profile!.fakePhone : contact.phone
                snapshotPhone    = formatPhone(rawPhone)
                snapshotNote     = profile?.fakeNote.isEmpty == false     ? profile!.fakeNote     : contact.note
                snapshotEmail    = profile?.fakeEmail.isEmpty == false    ? profile!.fakeEmail    : contact.email
                snapshotBirthday = profile?.fakeBirthday.isEmpty == false ? profile!.fakeBirthday : contact.birthday
                startTimer()
            }
            // Sauvegarde pour le peek bouton volume (persisté)
            trickEngine.markLastOpened(contact, phone: snapshotPhone)

            if hasPhoto {
                backgroundColor = contact.thumbnailImage?.dominantColor ?? Color(hex: "4f5054")
            }
        }
        .onDisappear { stopTimer() }
    }

    // MARK: - Header background (photo floutée + dégradé, comme Contacts)
    private var headerBackground: some View {
        GeometryReader { geo in
            ZStack {
                backgroundColor

                if let img = contact.thumbnailImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .blur(radius: 45, opaque: true)
                        .scaleEffect(1.2)
                }

                LinearGradient(stops: [
                    .init(color: .black.opacity(0.10), location: 0),
                    .init(color: .black.opacity(0.45), location: 0.55),
                    .init(color: .black, location: 1)
                ], startPoint: .top, endPoint: .bottom)
            }
            .clipped()
        }
    }

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

// MARK: - Action Button (cercle, comme Contacts)
struct ActionBtn: View {
    let icon: String
    var dimmed: Bool = false

    var body: some View {
        Circle()
            .fill(Color(hex: "2c2c2e"))
            .frame(width: 66, height: 66)
            .overlay(
                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundStyle(dimmed ? Color.white.opacity(0.4) : .white)
            )
    }
}

// MARK: - Data Card
struct DataCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content
            .padding(.horizontal, 14)
            .background(Color(hex: "1c1c1e"))
            .cornerRadius(12)
            .padding(.horizontal, 6)
    }
}

// MARK: - Bottom Row
struct BottomRow: View {
    let label: String
    let color: Color
    var body: some View {
        Button(action: {}) {
            Text(label)
                .font(.system(size: 17.7))
                .foregroundColor(color)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
        }
    }
}

// MARK: - Re-enable swipe back
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
