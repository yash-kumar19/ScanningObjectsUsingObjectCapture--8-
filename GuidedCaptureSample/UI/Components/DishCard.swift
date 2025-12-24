import SwiftUI

struct DishCard: View {
    let id: String
    let name: String
    let description: String
    let price: Double
    let category: String
    let image: String
    let onAddToCart: () -> Void
    var onClick: (() -> Void)? = nil
    
    var body: some View {
        Button(action: { onClick?() }) {
            GlassCard(padding: 0) {
                HStack(spacing: 16) {
                    // Image
                    ZStack {
                        AsyncImage(url: URL(string: image)) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Rectangle().fill(Color.gray.opacity(0.3))
                                    .overlay(
                                        Image(systemName: "photo")
                                            .foregroundColor(.white.opacity(0.3))
                                    )
                            }
                        }
                        .frame(width: 112, height: 112) // w-28 h-28
                        .clipped()
                        
                        // View 3D Overlay (simulated hover effect)
                        Color.black.opacity(0.0) // Placeholder for hover logic
                    }
                    .cornerRadius(20)
                    
                    // Info
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .top) {
                            Text(name)
                                .font(.headline)
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.bottom, 4)
                        
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(2)
                            .padding(.bottom, 8)
                        
                        // Category Pill
                        Text(category)
                            .font(.caption2)
                            .foregroundColor(Color(hex: "8b5cf6"))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color(hex: "8b5cf6").opacity(0.1))
                            .cornerRadius(100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 100)
                                    .stroke(Color(hex: "8b5cf6").opacity(0.3), lineWidth: 1)
                            )
                        
                        Spacer()
                    }
                    .frame(height: 112)
                    
                    // Price and Action
                    VStack(alignment: .trailing) {
                        Text(String(format: "$%.2f", price))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.primaryBlue)
                        
                        Spacer()
                        
                        Button(action: onAddToCart) {
                            Image(systemName: "plus")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Theme.gradientBlue)
                                .cornerRadius(16)
                                .shadow(color: Theme.primaryBlue.opacity(0.4), radius: 16, x: 0, y: 4)
                        }
                    }
                    .frame(height: 112)
                }
                .padding(16)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
