import SwiftUI

struct Theme {
    // Brand Colors (from React components)
    static let primaryBlue = Color(hex: "2b7fff")
    static let primaryPurple = Color(hex: "8b5cf6")
    
    // Semantic Colors (from globals.css .dark)
    static let background = Color(red: 0.05, green: 0.05, blue: 0.12)
    static let foreground = Color(hsl: "210 40% 98%")
    static let card = Color(hsl: "222.2 84% 4.9%")
    static let cardForeground = Color(hsl: "210 40% 98%")
    static let popover = Color(hsl: "222.2 84% 4.9%")
    static let popoverForeground = Color(hsl: "210 40% 98%")
    static let primary = Color(hsl: "210 40% 98%")
    static let primaryForeground = Color(hsl: "222.2 47.4% 11.2%")
    static let secondary = Color(hsl: "217.2 32.6% 17.5%")
    static let secondaryForeground = Color(hsl: "210 40% 98%")
    static let muted = Color(hsl: "217.2 32.6% 17.5%")
    static let mutedForeground = Color(hsl: "215 20.2% 65.1%")
    static let accent = Color(hsl: "217.2 32.6% 17.5%")
    static let accentForeground = Color(hsl: "210 40% 98%")
    static let destructive = Color(hsl: "0 62.8% 30.6%")
    static let destructiveForeground = Color(hsl: "210 40% 98%")
    static let border = Color(hsl: "217.2 32.6% 17.5%")
    static let input = Color(hsl: "217.2 32.6% 17.5%")
    static let ring = Color(hsl: "212.7 26.8% 83.9%")
    
    static let textPrimary = foreground
    static let textSecondary = mutedForeground
    
    static let gradientBlue = LinearGradient(
        gradient: Gradient(colors: [Color(hex: "2b7fff"), Color(hex: "3b82f6")]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let gradientPurple = LinearGradient(
        gradient: Gradient(colors: [Color(hex: "8b5cf6"), Color(hex: "a78bfa")]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension Color {
    init(hex: String) {
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
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    init(hsl: String) {
        // Format: "H S% L%" or "H S L"
        let components = hsl.components(separatedBy: " ").map { $0.replacingOccurrences(of: "%", with: "") }
        guard components.count == 3,
              let h = Double(components[0]),
              let s = Double(components[1]),
              let l = Double(components[2]) else {
            self.init(.black)
            return
        }
        
        self.init(hue: h / 360, saturation: s / 100, brightness: l / 100) // Note: SwiftUI Color(hue:...) uses HSB, not HSL. Need conversion.
        // Simple HSL to RGB conversion logic would be better here, but for now using HSB approximation or implementing conversion.
        // Actually, let's implement a proper HSL to Color init.
        
        let hue = h / 360
        let saturation = s / 100
        let lightness = l / 100
        
        let t2 = lightness < 0.5 ? lightness * (1 + saturation) : lightness + saturation - lightness * saturation
        let t1 = 2 * lightness - t2
        
        let r = Color.hueToRgb(t1, t2, hue + 1/3)
        let g = Color.hueToRgb(t1, t2, hue)
        let b = Color.hueToRgb(t1, t2, hue - 1/3)
        
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
    
    private static func hueToRgb(_ t1: Double, _ t2: Double, _ hue: Double) -> Double {
        var h = hue
        if h < 0 { h += 1 }
        if h > 1 { h -= 1 }
        if 6 * h < 1 { return t1 + (t2 - t1) * 6 * h }
        if 2 * h < 1 { return t2 }
        if 3 * h < 2 { return t1 + (t2 - t1) * (2/3 - h) * 6 }
        return t1
    }
    

}
