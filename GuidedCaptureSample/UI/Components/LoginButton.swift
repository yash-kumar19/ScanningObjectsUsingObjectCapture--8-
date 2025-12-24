import SwiftUI

struct LoginButton: View {
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {}) {
            HStack(spacing: 8) {
                Text("Login to manage your 3D menu")
                    .font(.system(size: 14, weight: .medium))
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(Color.fromHex("8B5CF6"))
            .opacity(isPressed ? 0.7 : 1.0)
            .shadow(color: Color.fromHex("8B5CF6").opacity(0.5), radius: 8, x: 0, y: 0)
            .shadow(color: Color.fromHex("8B5CF6").opacity(0.3), radius: 16, x: 0, y: 0)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}
