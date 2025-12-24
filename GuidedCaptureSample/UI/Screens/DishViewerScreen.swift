import SwiftUI

struct DishViewerScreen: View {
    // Callbacks
    var onBack: () -> Void
    var onAddToCart: () -> Void
    
    // State
    @State private var isRotating = true
    @State private var quantity = 1
    @State private var rotationAngle: Double = 0
    @State private var scale: CGFloat = 1.0
    
    // Data (Mock)
    let dish = (
        name: "Grilled Wagyu Steak",
        description: "Premium A5 Wagyu beef, grilled to perfection with seasonal vegetables and truffle butter sauce. Served with roasted potatoes.",
        price: 85.00,
        ingredients: ["Wagyu Beef", "Truffle Butter", "Seasonal Vegetables", "Red Wine Reduction"],
        allergens: ["Dairy"]
    )
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Hero 3D Viewer Section
                ZStack {
                    // Background Glows
                    ZStack {
                        Circle()
                            .fill(Theme.primaryBlue.opacity(0.3))
                            .frame(width: 400, height: 400)
                            .blur(radius: 100)
                            .offset(y: -50)
                        
                        Circle()
                            .fill(Theme.primaryPurple.opacity(0.2))
                            .frame(width: 300, height: 300)
                            .blur(radius: 80)
                            .offset(x: 100, y: 100)
                    }
                    
                    // 3D Model Placeholder
                    ZStack {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(LinearGradient(colors: [Theme.primaryBlue.opacity(0.1), Theme.primaryPurple.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 250, height: 250)
                            .overlay(
                                RoundedRectangle(cornerRadius: 28)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                            .shadow(color: Theme.primaryBlue.opacity(0.3), radius: 40)
                        
                        Text("🥩")
                            .font(.system(size: 100))
                            .scaleEffect(scale)
                            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: scale)
                    }
                    .rotation3DEffect(.degrees(rotationAngle), axis: (x: 0, y: 1, z: 0))
                    .onAppear {
                        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                            if isRotating {
                                rotationAngle = 360
                            }
                        }
                        withAnimation {
                            scale = 1.1
                        }
                    }
                    .onChange(of: isRotating) { rotating in
                        if rotating {
                            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                                rotationAngle = rotationAngle + 360
                            }
                        } else {
                            // Stop animation (SwiftUI animation control is tricky, simplistic here)
                            // In a real app with SceneKit, we'd pause the scene time.
                        }
                    }
                    
                    // Interaction Hint
                    VStack {
                        Spacer()
                        Text("Drag to rotate • Pinch to zoom")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                            .padding(.bottom, 80)
                    }
                    
                    // Controls
                    VStack {
                        Spacer()
                        HStack(spacing: 12) {
                            GhostButton(title: "Reset", icon: "arrow.counterclockwise") {
                                rotationAngle = 0
                            }
                            
                            GhostButton(title: isRotating ? "Pause" : "Auto Rotate", icon: isRotating ? "pause.fill" : "play.fill") {
                                isRotating.toggle()
                            }
                        }
                        .padding(.bottom, 24)
                    }
                    
                    // Header Controls
                    VStack {
                        HStack {
                            Button(action: onBack) {
                                Image(systemName: "arrow.left")
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            }
                            
                            Spacer()
                            
                            Button(action: {}) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 60) // Safe area
                        Spacer()
                    }
                }
                .frame(height: UIScreen.main.bounds.height * 0.55)
                
                // Details Section
                ScrollView {
                    VStack(spacing: 24) {
                        // Info Card
                        GlassCard {
                            VStack(alignment: .leading, spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(dish.name)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    
                                    Text(dish.description)
                                        .font(.body)
                                        .foregroundColor(Theme.textSecondary)
                                        .lineLimit(3)
                                }
                                
                                Divider().background(Color.white.opacity(0.1))
                                
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Price")
                                            .font(.caption)
                                            .foregroundColor(Theme.textSecondary)
                                        Text(String(format: "$%.2f", dish.price))
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundColor(Theme.primaryBlue)
                                    }
                                    
                                    Spacer()
                                    
                                    // Quantity Selector
                                    HStack(spacing: 16) {
                                        Button(action: { if quantity > 1 { quantity -= 1 } }) {
                                            Text("-")
                                                .font(.title2)
                                                .frame(width: 40, height: 40)
                                                .background(Color.white.opacity(0.05))
                                                .cornerRadius(12)
                                                .foregroundColor(.white)
                                        }
                                        
                                        Text("\(quantity)")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .frame(minWidth: 20)
                                        
                                        Button(action: { quantity += 1 }) {
                                            Text("+")
                                                .font(.title2)
                                                .frame(width: 40, height: 40)
                                                .background(Color.white.opacity(0.05))
                                                .cornerRadius(12)
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Ingredients
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Ingredients")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                FlowLayout(spacing: 8) {
                                    ForEach(dish.ingredients, id: \.self) { ingredient in
                                        Text(ingredient)
                                            .font(.caption)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.white.opacity(0.05))
                                            .cornerRadius(16)
                                            .foregroundColor(Theme.textSecondary)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                            )
                                    }
                                }
                                
                                if !dish.allergens.isEmpty {
                                    Divider().background(Color.white.opacity(0.1))
                                        .padding(.top, 8)
                                    
                                    HStack(spacing: 4) {
                                        Text("⚠️ Contains allergens:")
                                            .font(.caption)
                                            .foregroundColor(Theme.textSecondary)
                                        Text(dish.allergens.joined(separator: ", "))
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                        }
                        
                        // Actions
                        VStack(spacing: 12) {
                            PrimaryButton(
                                title: "Add to Cart • " + String(format: "$%.2f", dish.price * Double(quantity)),
                                icon: "cart.fill",
                                fullWidth: true,
                                action: onAddToCart
                            )
                            
                            SecondaryButton(title: "View Nutritional Info", fullWidth: true, action: {})
                        }
                        .padding(.bottom, 40)
                    }
                    .padding(.horizontal)
                    .padding(.top, 24)
                }
                .background(Theme.background)
                .cornerRadius(32, corners: [.topLeft, .topRight])
                .ignoresSafeArea(edges: .bottom)
            }
        }
    }
}

// Helper for rounded corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// Simple FlowLayout implementation
struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = flow(proposal: proposal, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = flow(proposal: proposal, subviews: subviews, spacing: spacing)
        for (index, point) in result.points.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    struct Result {
        var size: CGSize
        var points: [CGPoint]
    }

    func flow(proposal: ProposedViewSize, subviews: Subviews, spacing: CGFloat) -> Result {
        let maxWidth = proposal.width ?? 0
        var height: CGFloat = 0
        var points: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth {
                currentX = 0
                currentY += currentRowHeight + spacing
                currentRowHeight = 0
            }
            points.append(CGPoint(x: currentX, y: currentY))
            currentRowHeight = max(currentRowHeight, size.height)
            currentX += size.width + spacing
        }
        height = currentY + currentRowHeight
        return Result(size: CGSize(width: maxWidth, height: height), points: points)
    }
}
