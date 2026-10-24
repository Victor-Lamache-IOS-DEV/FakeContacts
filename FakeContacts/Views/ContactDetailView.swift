import SwiftUI
import UIKit

// MARK: - Scroll Offset Preference Key
struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

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
                    .fill(Color(hex: "a2a8b4"))
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
        GeometryReader { geo in
            let topInset = geo.safeAreaInsets.top

            ZStack(alignment: .top) {
                backgroundColor
                    .frame(height: topInset + 200)
                    .ignoresSafeArea()
                    .frame(maxHeight: .infinity, alignment: .top)

                ScrollView {
                    VStack(spacing: 0) {

                        // ── HEADER ──────────────────────────────────
                        ZStack(alignment: .bottom) {
                            LinearGradient(
                                colors: [backgroundColor, Color(hex: "272a33")],
                                startPoint: .top,
                                endPoint: .bottom
                            )

                            VStack(spacing: 0) {
                                Spacer().frame(height: topInset - 10)

                                AvatarView(contact: contact, size: hasPhoto ? 270 : 110)
                                    .padding(.bottom, 14)

                                Text(contact.name)
                                    .font(.system(size: hasPhoto ? 34 : 28, weight: .semibold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 20)

                                HStack(spacing: 10) {
                                    ActionBtn(icon: "message.fill", label: "message")
                                    ActionBtn(icon: "phone.fill",   label: "call")
                                    ActionBtn(icon: "video.fill",   label: "video")
                                    ActionBtn(icon: "envelope.fill", label: "mail", dimmed: true)
                                }
                                .padding(.horizontal, 8)
                                .padding(.bottom, 24)
                            }
                        }
                        .frame(height: hasPhoto ? topInset + 430 : topInset + 250)

                        // ── DATA ZONE ────────────────────────────────
                        VStack(spacing: 10) {

                            DataCard {
                                HStack(spacing: 12) {
                                    AvatarView(contact: contact, size: 40)
                                    Text("Contact Photo & Poster")
                                        .font(.system(size: 17.7))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13.5, weight: .semibold))
                                        .foregroundColor(Color(.systemGray3))
                                }
                                .padding(.vertical, 10)
                            }

                            if !snapshotPhone.isEmpty {
                                DataCard {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("mobile")
                                            .font(.system(size: 13.5))
                                            .foregroundColor(.secondary)
                                        Text(snapshotPhone)
                                            .font(.system(size: 17.7))
                                            .foregroundColor(.blue)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 10)
                                }
                            }

                            DataCard {
                                HStack {
                                    Text("FaceTime")
                                        .font(.system(size: 17.7))
                                        .foregroundColor(.white)
                                    Spacer()
                                    HStack(spacing: 10) {
                                        FaceTimeBtn(icon: "video.fill")
                                        FaceTimeBtn(icon: "phone.fill")
                                    }
                                }
                                .padding(.vertical, 16)
                            }

                            if !snapshotEmail.isEmpty {
                                DataCard {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("email")
                                            .font(.system(size: 13.5))
                                            .foregroundColor(.secondary)
                                        Text(snapshotEmail)
                                            .font(.system(size: 17.7))
                                            .foregroundColor(.blue)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
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
                                            .foregroundColor(.white)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 10)
                                }
                            }

                            DataCard {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Notes")
                                        .font(.system(size: 13.5))
                                        .foregroundColor(.secondary)
                                    if !snapshotNote.isEmpty {
                                        Text(snapshotNote)
                                            .font(.system(size: 17.7))
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
                                .padding(.vertical, 10)
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
                        .padding(.top, 12)
                        .background(Color.black)
                    }
                }
                .ignoresSafeArea(edges: .top)
            }
            .background(Color.black)
        }
        .navigationBarBackButtonHidden(true)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 32, height: 32)
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.leading, 4)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Text("Edit")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 30)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
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
            // Save for volume-button trick
            trickEngine.lastOpenedName  = contact.name
            trickEngine.lastOpenedPhone = snapshotPhone.filter { $0.isNumber }
            
            // Calculate background color once
            if hasPhoto {
                backgroundColor = contact.thumbnailImage?.dominantColor ?? Color(hex: "4f5054")
            }
        }
        .onDisappear { stopTimer() }
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

// MARK: - Action Button
struct ActionBtn: View {
    let icon: String
    let label: String
    var dimmed: Bool = false

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(hex: "41434f"))
            .frame(height: 60)
            .overlay(
                VStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(dimmed ? .white.opacity(0.35) : .white)
                    Text(label)
                        .font(.system(size: 11.4))
                        .foregroundColor(dimmed ? .white.opacity(0.35) : .white.opacity(0.8))
                }
            )
            .frame(maxWidth: .infinity)
    }
}

// MARK: - FaceTime Button
struct FaceTimeBtn: View {
    let icon: String
    var body: some View {
        Circle()
            .fill(Color(hex: "2c2c2e"))
            .frame(width: 36, height: 36)
            .overlay(
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(.blue)
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
            .cornerRadius(10)
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
