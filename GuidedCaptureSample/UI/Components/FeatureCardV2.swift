import SwiftUI

struct FeatureCardV2: View {
    let icon: String
    let iconColor: Color
    let iconBackground: LinearGradient
    let title: String
    let description: String
    
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon container with gradient
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(iconBackground)
                    .frame(width: 56, height: 56)
                    .shadow(color: iconColor.opacity(0.2), radius: 4, x: 0, y: 2)
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
            }
            
            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(Color.fromHex("9CA3AF"))
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            ZStack {
                // Glass blur effect
                Color.fromHex("1A1F2E").opacity(0.6)
                
                // Subtle gradient overlay
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.05),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.1),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}
