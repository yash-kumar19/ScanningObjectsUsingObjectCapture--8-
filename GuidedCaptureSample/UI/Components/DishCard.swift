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
        HStack(alignment: .top, spacing: 16) {
            // Info Section (Left) - Tapping this opens the detail sheet
            VStack(alignment: .leading, spacing: 8) {
                // Veg badge representation & Category
                HStack(spacing: 6) {
                    // Small colored dot to represent category / food type
                    Circle()
                        .fill(category.lowercased().contains("drink") || category.lowercased().contains("bevrage") ? Color.blue : Color.green)
                        .frame(width: 8, height: 8)
                        .padding(3)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(category.lowercased().contains("drink") || category.lowercased().contains("bevrage") ? Color.blue.opacity(0.5) : Color.green.opacity(0.5), lineWidth: 1)
                        )
                    
                    Text(category)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.5))
                }
                
                Text(name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                
                Text(String(format: "$%.2f", price))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(hex: "60a5fa")) // Blue price
                
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.6))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .contentShape(Rectangle()) // Make the whole text column tappable
            .onTapGesture {
                onClick?()
            }
            
            Spacer()
            
            // Image and Buttons Section (Right)
            ZStack(alignment: .bottom) {
                // Main Image - Tapping this opens the detail sheet
                ZStack {
                    CachedAsyncImage(url: URL(string: image)) { phase in
                        switch phase {
                        case .empty:
                            Rectangle().fill(Color.white.opacity(0.05))
                        case .success(let img):
                            img.resizable().aspectRatio(contentMode: .fill)
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
                .frame(width: 128, height: 128)
                .cornerRadius(16)
                .clipped()
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    onClick?()
                }
                
                // 3D Tag
                if hasModel {
                    HStack(spacing: 3) {
                        Image(systemName: "arkit")
                            .font(.system(size: 8, weight: .bold))
                        Text("3D")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(hex: "8b5cf6"))
                    .cornerRadius(6)
                    .padding(6)
                    .frame(width: 128, height: 128, alignment: .topTrailing)
                    .allowsHitTesting(false) // Pass touch events to image onTapGesture
                }
                
                // Buttons overlapping the bottom (Intercepts taps and bypasses detail sheet)
                HStack(spacing: 6) {
                    if hasModel {
                        // View 3D Button
                        Button(action: {
                            onViewAR?()
                        }) {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(Color(hex: "8b5cf6"))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Add Button
                    Button(action: onAddToCart) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                            Text("ADD")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(Color(hex: "3b82f6"))
                        .cornerRadius(14)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(4)
                .background(Color(hex: "1e293b"))
                .cornerRadius(18)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 4, x: 0, y: 2)
                .offset(y: 14) // Overlap bottom edge of image
            }
            .frame(width: 128, height: 128)
            .padding(.bottom, 16) // Spacing for overlap
        }
        .padding(16)
        .background(Color(hex: "0f172a")) // Slightly darker for refined look
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

