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

// MARK: - Muted background color from a photo
//
// Moyenne fiable via Core Image, puis désaturation + assombrissement pour
// obtenir le fond uni gris-bleu de la fiche Contacts de référence.
private let ciContext = CIContext(options: nil)

extension UIImage {
    var mutedBackgroundColor: Color? {
        guard let ciImage = CIImage(image: self),
              let filter = CIFilter(name: "CIAreaAverage") else { return nil }

        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: ciImage.extent), forKey: kCIInputExtentKey)
        guard let output = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        ciContext.render(output, toBitmap: &bitmap, rowBytes: 4,
                         bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                         format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())

        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(red:   CGFloat(bitmap[0]) / 255,
                green: CGFloat(bitmap[1]) / 255,
                blue:  CGFloat(bitmap[2]) / 255,
                alpha: 1).getHue(&h, saturation: &s, brightness: &b, alpha: &a)

        let saturation = min(max(s * 0.8, 0.08), 0.20)
        let brightness = min(max(b * 0.55, 0.28), 0.42)
        return Color(hue: Double(h), saturation: Double(saturation), brightness: Double(brightness))
    }
}

// MARK: - Avatar View
struct AvatarView: View {
    let contact: Contact
    let size: CGFloat
    var large: Bool = false

    var body: some View {
        if let img = contact.thumbnailImage {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            ZStack {
                if large {
                    // Grand avatar sans photo : cercle translucide cerclé.
                    Circle().fill(Color.white.opacity(0.05))
                    Circle().strokeBorder(Color.white.opacity(0.22), lineWidth: 1.2)
                } else {
                    // Petit avatar : dégradé violet-gris fixe, aucune couleur aléatoire.
                    Circle().fill(
                        LinearGradient(colors: [Color(hex: "6C6478"), Color(hex: "4A4456")],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                }
                Text(initials)
                    .font(.system(size: size * (large ? 0.44 : 0.42),
                                  weight: large ? .regular : .medium))
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

    // Fond uni (contact avec photo) — valeur de repli avant le calcul.
    @State private var photoBackground: Color = Color(hex: "5B6870")

    init(contact: Contact, fromSearch: Bool = false, searchPrefix: String = "") {
        self.contact = contact
        self.fromSearch = fromSearch
        self.searchPrefix = searchPrefix
    }

    var body: some View {
        ZStack {
            // Fond plein écran, TOTALEMENT séparé du ScrollView :
            // il passe derrière la barre d'état et la barre de navigation,
            // donc le haut ne peut jamais être coupé ni créer de couture.
            Color.black
                .ignoresSafeArea()

            background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {

                    AvatarView(contact: contact, size: 200, large: true)
                        .padding(.top, 24)
                        .padding(.bottom, 26)

                    Text(contact.name)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)

                    HStack(spacing: 14) {
                        ActionBtn(icon: "message.fill")
                        ActionBtn(icon: "phone.fill")
                        ActionBtn(icon: "video.fill")
                        ActionBtn(icon: "envelope.fill", dimmed: true)
                    }
                    .padding(.bottom, 24)

                    VStack(spacing: 10) {

                        DataCard {
                            HStack(spacing: 12) {
                                AvatarView(contact: contact, size: 40)
                                Text("Contact Photo & Poster")
                                    .font(.system(size: 17))
                                    .foregroundStyle(.white)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.35))
                            }
                            .padding(.vertical, 10)
                        }

                        // Téléphone + Notes dans une seule carte (comme Contacts)
                        DataCard {
                            VStack(alignment: .leading, spacing: 0) {
                                if !snapshotPhone.isEmpty {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text("phone")
                                                .font(.system(size: 13))
                                                .foregroundStyle(Color.white.opacity(0.55))
                                            Text(snapshotPhone)
                                                .font(.system(size: 17))
                                                .foregroundStyle(.white)
                                        }
                                        Spacer()
                                        Image(systemName: "phone.fill")
                                            .font(.system(size: 17))
                                            .foregroundStyle(.white)
                                    }
                                    .padding(.vertical, 12)

                                    Divider()
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Notes")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.white.opacity(0.55))
                                    if !snapshotNote.isEmpty {
                                        Text(snapshotNote)
                                            .font(.system(size: 17))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .frame(maxWidth: .infinity, minHeight: 70, alignment: .topLeading)
                                .padding(.vertical, 12)
                            }
                        }

                        if !snapshotEmail.isEmpty {
                            DataCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("email")
                                            .font(.system(size: 13))
                                            .foregroundStyle(Color.white.opacity(0.55))
                                        Text(snapshotEmail)
                                            .font(.system(size: 17))
                                            .foregroundStyle(.white)
                                    }
                                    Spacer()
                                    Image(systemName: "envelope.fill")
                                        .font(.system(size: 17))
                                        .foregroundStyle(.white)
                                }
                                .padding(.vertical, 10)
                            }
                        }

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
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 10)
                            }
                        }

                        DataCard {
                            VStack(spacing: 0) {
                                BottomRow(label: "Send Message")
                                Divider()
                                BottomRow(label: "Share Contact")
                                Divider()
                                BottomRow(label: "Add to Favourites")
                            }
                        }

                        DataCard { BottomRow(label: "Add to Emergency Contacts") }
                        DataCard { BottomRow(label: "Share my Location") }

                        Spacer().frame(height: 24)
                    }
                    .padding(.horizontal, 22)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        // Barre transparente : le fond plein écran reste continu derrière.
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background { Circle().fill(Color.black) }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Text("Edit")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background { Capsule().fill(Color.black) }
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

            if let img = contact.thumbnailImage,
               let muted = img.mutedBackgroundColor {
                photoBackground = muted
            }
        }
        .onDisappear { stopTimer() }
    }

    // MARK: - Full-screen background
    @ViewBuilder
    private var background: some View {
        if contact.thumbnailImage != nil {
            // Couleur unie dérivée de la photo, comme la fiche de référence.
            photoBackground
        } else {
            // Sans photo : dégradé fixe bleu-gris → lavande → sombre.
            LinearGradient(stops: [
                .init(color: Color(hex: "A6B0B7"), location: 0.00),
                .init(color: Color(hex: "8E99A6"), location: 0.22),
                .init(color: Color(hex: "8A86A4"), location: 0.45),
                .init(color: Color(hex: "4B4557"), location: 0.70),
                .init(color: Color(hex: "24202C"), location: 0.88),
                .init(color: Color(hex: "151319"), location: 1.00)
            ], startPoint: .top, endPoint: .bottom)
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
            .fill(Color.black.opacity(0.55))
            .frame(width: 62, height: 62)
            .overlay(
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(dimmed ? Color.white.opacity(0.35) : .white)
            )
    }
}

// MARK: - Data Card
struct DataCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, 16)
            .background(Color.black.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Bottom Row
struct BottomRow: View {
    let label: String

    var body: some View {
        Button(action: {}) {
            Text(label)
                .font(.system(size: 17))
                .foregroundStyle(.white)
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
