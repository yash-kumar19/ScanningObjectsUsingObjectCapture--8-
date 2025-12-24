import SwiftUI

struct RestaurantCard: View {
    let id: String
    let name: String
    let image: String
    let rating: Double
    let cuisine: String
    let location: String
    let priceRange: String
    let onClick: () -> Void
    
    var body: some View {
        Button(action: onClick) {
            VStack(spacing: 0) {
                // Image Header
                ZStack(alignment: .topLeading) {
                    AsyncImage(url: URL(string: image)) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                        }
                    }
                    .frame(width: 280, height: 160)
                    .clipped()
                    
                    // Subtle gradient overlay
                    LinearGradient(
                        colors: [Color.black.opacity(0.4), Color.clear],
                        startPoint: .bottom,
                        endPoint: .center
                    )
                    .frame(width: 280, height: 160)
                    
                    // Badges Overlay
                    VStack {
                        HStack(spacing: 8) {
                            // Rating Badge
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.yellow)
                                Text(String(format: "%.1f", rating))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                            
                            Spacer()
                            
                            // Price Badge
                            Text(priceRange)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(8)
                        }
                        .padding(10)
                        Spacer()
                    }
                }
                
                // Info Section
                VStack(alignment: .leading, spacing: 8) {
                    Text(name)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(cuisine)
                        .font(.subheadline)
                        .foregroundColor(Color.fromHex("3B82F6"))
                    
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption)
                            .foregroundColor(Color.fromHex("9CA3AF"))
                        Text(location)
                            .font(.caption)
                            .foregroundColor(Color.fromHex("9CA3AF"))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.white.opacity(0.05))
            }
            .frame(width: 280)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
