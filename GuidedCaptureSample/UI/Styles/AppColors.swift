import SwiftUI

// MARK: - Color Extension
extension Color {
    // MARK: - Brand Colors
    static let brandPrimary = Color(hex: "3B82F6") // Blue
    static let brandPurple = Color(hex: "8B5CF6")
    
    // MARK: - Background Colors
    static let appBackground = Color(hex: "0A0E1A")
    static let cardBackground = Color(hex: "1A1F2E")
    static let cardBackgroundLight = Color(hex: "1E2532")
    
    // MARK: - Text Colors
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "9CA3AF")
    static let textMuted = Color(hex: "6B7280")
    
    // MARK: - Accent Colors
    static let accentBlue = Color(hex: "3B82F6")
    static let accentPurple = Color(hex: "8B5CF6")
    static let accentGreen = Color(hex: "10B981")
    static let accentYellow = Color(hex: "F59E0B")
    
    // MARK: - Gradients
    static let heroGradient = LinearGradient(
        colors: [
            Color(hex: "1E3A8A"),
            Color(hex: "1E40AF"),
            Color(hex: "3B82F6").opacity(0.3)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let cardGradient = LinearGradient(
        colors: [
            Color(hex: "1A1F2E"),
            Color(hex: "1E2532")
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
