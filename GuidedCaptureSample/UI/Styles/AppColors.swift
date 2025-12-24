import SwiftUI

// MARK: - Color Extension
extension Color {
    // MARK: - Brand Colors
    static let brandPrimary = Color.fromHex("3B82F6") // Blue
    static let brandPurple = Color.fromHex("8B5CF6")
    
    // MARK: - Background Colors
    static let appBackground = Color.fromHex("0A0E1A")
    static let cardBackground = Color.fromHex("1A1F2E")
    static let cardBackgroundLight = Color.fromHex("1E2532")
    
    // MARK: - Text Colors
    static let textPrimary = Color.white
    static let textSecondary = Color.fromHex("9CA3AF")
    static let textMuted = Color.fromHex("6B7280")
    
    // MARK: - Accent Colors
    static let accentBlue = Color.fromHex("3B82F6")
    static let accentPurple = Color.fromHex("8B5CF6")
    static let accentGreen = Color.fromHex("10B981")
    static let accentYellow = Color.fromHex("F59E0B")
    
    // MARK: - Gradients
    static let heroGradient = LinearGradient(
        colors: [
            Color.fromHex("1E3A8A"),
            Color.fromHex("1E40AF"),
            Color.fromHex("3B82F6").opacity(0.3)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let cardGradient = LinearGradient(
        colors: [
            Color.fromHex("1A1F2E"),
            Color.fromHex("1E2532")
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // MARK: - Hex Helper
    static func fromHex(_ hex: String) -> Color {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 255, 255, 255)
        }
        
        return Color(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    
}
