import SwiftUI

// ── Brand colours (put *all* colour helpers in one file) ────────────────
extension Color {
    static let brandPrimary   = Color(red: 0.14, green: 0.46, blue: 0.95)
    static let brandSecondary = Color(red: 0.34, green: 0.74, blue: 0.99)

    // Legacy names to avoid changing other files
    static let skyBlue = brandPrimary
    static let back    = Color(uiColor: .systemBackground)
}

// ── Rounded “senior” font modifier ─────────────────────────────────────
struct SeniorFont: ViewModifier {
    func body(content: Content) -> some View {
        content.font(.system(.body, design: .rounded))
    }
}

// ── Gradient button ────────────────────────────────────────────────────
struct BigButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, minHeight: 52)
            .modifier(SeniorFont())
            .foregroundColor(.white)
            .background(
                LinearGradient(colors: [.brandPrimary, .brandSecondary],
                               startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

// ── Circular progress ring ─────────────────────────────────────────────
struct ProgressRing: View {
    let progress: Double   // 0…1
    let baseColor: Color
    let allDone: Bool

    var body: some View {
        ZStack {
            Circle().stroke(baseColor.opacity(0.20), lineWidth: 16)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(allDone ? .green : baseColor,
                        style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: progress)
        }
        .frame(width: 128, height: 128)
    }
}
