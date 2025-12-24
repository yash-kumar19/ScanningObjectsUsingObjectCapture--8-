import SwiftUI

struct GhostButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void
    
    @State private var isHovered = false
    
    init(title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                }
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .frame(height: 36)
            .padding(.horizontal, 16)
            .background(isHovered ? Color.white.opacity(0.05) : Color.clear)
            .foregroundColor(Theme.primaryBlue)
            .cornerRadius(12)
        }
    }
}
