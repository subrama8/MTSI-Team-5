import SwiftUI

extension Color {
    // ── Brand palette ──
    static let brandPrimary   = Color(red: 0.14, green: 0.46, blue: 0.95)
    static let brandSecondary = Color(red: 0.34, green: 0.74, blue: 0.99)

    // ── Existing fallback names ──
    static let skyBlue = brandPrimary
    static let back    = Color(uiColor: .systemBackground)
}
