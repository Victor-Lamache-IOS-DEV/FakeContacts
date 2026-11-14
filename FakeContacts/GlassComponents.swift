import SwiftUI

// MARK: - iOS 26 Glass Effects
//
// iOS 26 introduces a new glass design language. We use `.glassEffect()` when
// available and fall back to `.ultraThinMaterial` / `.thinMaterial` on older
// releases so the app keeps working while looking modern on iOS 26.

// A glass panel that blurs whatever is behind it.
struct GlassPanel<Content: View>: View {
    @ViewBuilder let content: Content
    var tint: Color = .white.opacity(0.08)
    var cornerRadius: CGFloat = 16

    var body: some View {
        content
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background {
                if #available(iOS 26.0, *) {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .glassEffect()
                        .tint(tint)
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .stroke(tint.opacity(0.35), lineWidth: 1)
                        )
                }
            }
    }
}

// MARK: - Glass List Row

struct GlassRow<Content: View>: View {
    @ViewBuilder let content: Content
    var isArmed: Bool = false

    var body: some View {
        content
            .listRowBackground(
                Group {
                    if #available(iOS 26.0, *) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .glassEffect()
                            .tint(isArmed ? .red.opacity(0.15) : .white.opacity(0.06))
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(isArmed ? 0.10 : 0.06))
                    }
                }
            )
            .listRowSeparator(.hidden)
            .padding(.vertical, 4)
            .padding(.horizontal, 2)
    }
}

// MARK: - Glass Card (detail view)

struct GlassCard<Content: View>: View {
    @ViewBuilder let content: Content
    var tint: Color = .white.opacity(0.08)

    var body: some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                if #available(iOS 26.0, *) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .glassEffect()
                        .tint(tint)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(hex: "1c1c1e"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 6)
    }
}

// MARK: - Glass Toolbar Button

struct GlassToolbarButton: View {
    let icon: String
    let action: () -> Void
    var tint: Color = .white

    var body: some View {
        Button(action: action) {
            ZStack {
                if #available(iOS 26.0, *) {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .glassEffect()
                        .tint(tint.opacity(0.1))
                        .frame(width: 34, height: 34)
                } else {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 34, height: 34)
                }
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(tint)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shimmer Effect (new visual effect)

struct Shimmer: ViewModifier {
    @State private var phase = 0.0
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.white.opacity(isActive ? 0.35 : 0),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(30))
                .frame(width: 200, height: 200)
                .offset(x: isActive ? 220 : -220)
                .animation(
                    .linear(duration: 1.6).repeatForever(autoreverses: false),
                    value: isActive
                )
                .onAppear {
                    if isActive { phase = 1 }
                },
                alignment: .center
            )
            .clipped()
    }
}

extension View {
    func shimmer(_ isActive: Bool) -> some View {
        self.modifier(Shimmer(isActive: isActive))
    }
}

// MARK: - Armed State Pulse

struct ArmedPulse: ViewModifier {
    @State private var pulse = false
    let isArmed: Bool

    func body(content: Content) -> some View {
        content
            .overlay(
                Circle()
                    .stroke(Color.red.opacity(isArmed ? 0.5 : 0), lineWidth: 2)
                    .scaleEffect(pulse ? 1.4 : 1.0)
                    .opacity(pulse ? 0 : (isArmed ? 0.7 : 0))
                    .animation(
                        .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                        value: pulse
                    )
                    .onAppear {
                        if isArmed { pulse = true }
                    }
            )
    }
}

extension View {
    func armedPulse(_ isArmed: Bool) -> some View {
        self.modifier(ArmedPulse(isArmed: isArmed))
    }
}
