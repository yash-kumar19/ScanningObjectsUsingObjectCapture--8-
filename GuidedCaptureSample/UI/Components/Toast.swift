import SwiftUI

enum ToastType {
    case success
    case error
    case info
    case warning
    
    var icon: String {
        switch self {
        case .success: return "checkmark"
        case .error: return "xmark"
        case .info: return "info.circle"
        case .warning: return "exclamationmark.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .success: return Color.green
        case .error: return Color.red
        case .info: return Theme.primaryBlue
        case .warning: return Color.yellow
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .success: return Color.green.opacity(0.1)
        case .error: return Color.red.opacity(0.1)
        case .info: return Theme.primaryBlue.opacity(0.1)
        case .warning: return Color.yellow.opacity(0.1)
        }
    }
    
    var borderColor: Color {
        switch self {
        case .success: return Color.green.opacity(0.3)
        case .error: return Color.red.opacity(0.3)
        case .info: return Theme.primaryBlue.opacity(0.3)
        case .warning: return Color.yellow.opacity(0.3)
        }
    }
}

struct Toast: View {
    let message: String
    let type: ToastType
    let onClose: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(type.color)
            
            Text(message)
                .font(.body)
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.05))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            }
        }
        .padding(16)
        .background(
            ZStack {
                Color.white.opacity(0.05)
                type.backgroundColor
            }
        )
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(type.borderColor, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 32, x: 0, y: 8)
        .padding(.horizontal, 16)
    }
}

struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    let type: ToastType
    
    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            
            if isPresented {
                Toast(message: message, type: type, onClose: {
                    withAnimation {
                        isPresented = false
                    }
                })
                .padding(.top, 60) // Adjust based on safe area
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(100)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            isPresented = false
                        }
                    }
                }
            }
        }
    }
}

extension View {
    func toast(isPresented: Binding<Bool>, message: String, type: ToastType = .info) -> some View {
        self.modifier(ToastModifier(isPresented: isPresented, message: message, type: type))
    }
}
