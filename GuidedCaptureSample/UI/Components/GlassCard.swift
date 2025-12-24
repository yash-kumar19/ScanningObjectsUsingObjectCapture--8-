import SwiftUI

struct GlassCard<Content: View>: View {
    var padding: CGFloat = 16
    let content: Content
    
    init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(Color.white.opacity(0.05))  // bg-card from React
            .cornerRadius(12)  // rounded-xl = 12px
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)  // border-border
            )
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)  // Subtle shadow
    }
}
