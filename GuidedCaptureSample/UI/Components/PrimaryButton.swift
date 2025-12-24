import SwiftUI

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var fullWidth: Bool = false
    var size: ButtonSize = .default
    let action: () -> Void
    
    @State private var isPressed = false
    
    enum ButtonSize {
        case sm, `default`, lg
        
        var height: CGFloat {
            switch self {
            case .sm: return 32
            case .default: return 36  // h-9 from React
            case .lg: return 40
            }
        }
        
        var horizontalPadding: CGFloat {
            switch self {
            case .sm: return 12
            case .default: return 16  // px-4 from React
            case .lg: return 20
            }
        }
        
        var fontSize: Font {
            switch self {
            case .sm: return .caption
            case .default: return .subheadline
            case .lg: return .body
            }
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: icon != nil ? 8 : 0) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                }
                Text(title)
                    .font(size.fontSize)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: size.height)
            .padding(.horizontal, size.horizontalPadding)
            .background(Theme.primaryBlue)  // Solid color, no gradient
            .foregroundColor(.white)
            .cornerRadius(8)  // rounded-md = 8px
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)  // Subtle shadow
            .opacity(isPressed ? 0.9 : 1.0)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}
