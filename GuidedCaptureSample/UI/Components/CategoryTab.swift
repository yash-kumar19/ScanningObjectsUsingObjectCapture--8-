import SwiftUI

struct CategoryTab: View {
    let label: String
    let count: Int?
    let isSelected: Bool
    let onClick: () -> Void
    var icon: String? = nil
    
    var body: some View {
        Button(action: onClick) {
            ZStack {
                // Glow effect when selected
                if isSelected {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [Theme.primaryBlue, Theme.primaryBlue.opacity(0.8)], // Adjust to match #3b82f6
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .blur(radius: 12) // blur-xl roughly
                        .opacity(0.3)
                }
                
                HStack(spacing: 8) {
                    if let icon = icon {
                        Image(systemName: icon)
                    }
                    
                    Text(label)
                        .fontWeight(.medium)
                    
                    if let count = count {
                        Text("\(count)")
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(isSelected ? Theme.primaryBlue : Color.white.opacity(0.1))
                            .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .frame(minHeight: 52)
                .background(
                    isSelected ? 
                    AnyView(
                        LinearGradient(
                            colors: [Theme.primaryBlue.opacity(0.2), Theme.primaryBlue.opacity(0.1)], // Adjust to match #3b82f6/20
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    ) : 
                    AnyView(Color.white.opacity(0.02))
                )
                .foregroundColor(isSelected ? Theme.primaryBlue : .white.opacity(0.7))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            isSelected ? Theme.primaryBlue : Color.white.opacity(0.08),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: isSelected ? Theme.primaryBlue.opacity(0.3) : .clear,
                    radius: 32, x: 0, y: 8
                )
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
