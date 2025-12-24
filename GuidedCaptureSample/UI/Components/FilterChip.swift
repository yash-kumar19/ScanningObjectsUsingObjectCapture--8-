import SwiftUI

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    var icon: String? = nil
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(label)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .frame(minHeight: 52)
            .background(
                isSelected ? 
                AnyView(Theme.gradientBlue) : 
                AnyView(Color.white.opacity(0.02))
            )
            .foregroundColor(isSelected ? .white : .white.opacity(0.7))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected ? Theme.primaryBlue : Color.white.opacity(0.08),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: isSelected ? Theme.primaryBlue.opacity(0.4) : .clear,
                radius: 32, x: 0, y: 8
            )
        }
    }
}
