import SwiftUI

struct DishCard: View {
    let id: String
    let name: String
    let description: String
    let price: Double
    let category: String
    let image: String
    var hasModel: Bool = false
    let onAddToCart: () -> Void
    var onClick: (() -> Void)? = nil
    var onViewAR: (() -> Void)? = nil
    
    var body: some View {
        Button(action: { onClick?() }) {
            HStack(spacing: 16) {
                // Image
                ZStack {
                    AsyncImage(url: URL(string: image)) { phase in
                        switch phase {
                        case .empty:
                            Rectangle().fill(Color.white.opacity(0.05))
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        case .failure:
                            Rectangle().fill(Color.white.opacity(0.05))
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.white.opacity(0.3))
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
                .frame(width: 80, height: 80)
                .cornerRadius(16)
                .clipped()
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                
                // Info
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(name)
                            .font(.system(size: 16, weight: .bold)) // Bolder title
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        // AR Badge if model exists
                        if hasModel {
                            Image(systemName: "arkit")
                                .font(.caption)
                                .foregroundColor(Color(hex: "60a5fa")) // Blue-400
                        }
                    }
                    
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.6))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        Text(category)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(hex: "c7d2fe")) // Indigo-200
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(hex: "4338ca").opacity(0.3)) // Indigo-700 w/ opacity
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(hex: "6366f1").opacity(0.3), lineWidth: 1)
                            )
                        
                        Spacer()
                    }
                    .padding(.top, 2)
                }
                
                Spacer()
                
                // Price and Action
                VStack(alignment: .trailing, spacing: 12) {
                    Text(String(format: "$%.2f", price))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: "60a5fa")) // Blue-400
                    
                    Button(action: {
                        if hasModel {
                            onViewAR?() 
                        } else {
                            onAddToCart()
                        }
                    }) {
                        Image(systemName: hasModel ? "cube.transparent" : "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36) // Slightly larger button
                            .background(Color(hex: "3b82f6")) // Blue-500
                            .clipShape(Circle())
                            .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(hex: "1e293b")) // Dark slate
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
