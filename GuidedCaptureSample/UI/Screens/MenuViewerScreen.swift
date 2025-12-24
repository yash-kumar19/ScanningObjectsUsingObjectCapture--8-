import SwiftUI

struct MenuViewerScreen: View {
    // Callbacks
    var onBack: () -> Void
    
    // State
    @State private var selectedDishIndex = 0
    @State private var isRotating = true
    @State private var rotationAngle: Double = 0
    @State private var scale: CGFloat = 1.0
    
    // Data
    let dishes = [
        Restaurant(id: "1", name: "Grilled Wagyu Steak", image: "", rating: 0, category: "Mains", dishes: 0),
        Restaurant(id: "2", name: "Lobster Thermidor", image: "", rating: 0, category: "Seafood", dishes: 0),
        Restaurant(id: "3", name: "Truffle Risotto", image: "", rating: 0, category: "Mains", dishes: 0)
    ]
    
    let dishDetails: [String: (description: String, price: String, ingredients: [String])] = [
        "1": ("Premium A5 Wagyu beef, grilled to perfection with seasonal vegetables and truffle sauce", "$85.00", ["Wagyu Beef", "Truffle", "Seasonal Vegetables", "Red Wine Sauce"]),
        "2": ("Fresh Atlantic lobster in creamy cognac sauce with parmesan crust", "$65.00", ["Lobster", "Cognac", "Parmesan", "Cream"]),
        "3": ("Creamy arborio rice with black truffle shavings and aged parmesan", "$45.00", ["Arborio Rice", "Black Truffle", "Parmesan", "White Wine"])
    ]
    
    var selectedDish: Restaurant {
        dishes[selectedDishIndex]
    }
    
    var selectedDetails: (description: String, price: String, ingredients: [String]) {
        dishDetails[selectedDish.id] ?? ("", "", [])
    }
    
    var body: some View {
        ZStack {
            GlowBackground()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "arrow.left")
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.05))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                    
                    Spacer()
                    
                    Text("3D Menu")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {}) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.05))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                }
                .padding(24)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 3D Viewer Card
                        GlassCard(padding: 0) {
                            VStack(spacing: 0) {
                                // 3D Placeholder
                                ZStack {
                                    LinearGradient(colors: [Color(hex: "0B0F1A"), Color(hex: "050505")], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        .frame(height: 350)
                                    
                                    // Lighting Effects
                                    Circle()
                                        .fill(Color.white.opacity(0.3))
                                        .frame(width: 128, height: 128)
                                        .blur(radius: 80)
                                        .offset(x: -100, y: -100)
                                    
                                    Circle()
                                        .fill(Theme.primaryBlue.opacity(0.2))
                                        .frame(width: 160, height: 160)
                                        .blur(radius: 100)
                                        .offset(x: 100, y: 100)
                                    
                                    // Mock 3D Object
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 24)
                                            .fill(LinearGradient(colors: [Theme.primaryBlue, Theme.primaryPurple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                            .frame(width: 192, height: 192)
                                            .shadow(color: Theme.primaryBlue.opacity(0.5), radius: 20)
                                        
                                        Text("🥩")
                                            .font(.system(size: 80))
                                            .scaleEffect(scale)
                                    }
                                    .rotation3DEffect(.degrees(rotationAngle), axis: (x: 0, y: 1, z: 0))
                                    .onAppear {
                                        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                                            rotationAngle = 360
                                        }
                                        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                                            scale = 1.1
                                        }
                                    }
                                    
                                    // Hint
                                    VStack {
                                        Spacer()
                                        Text("Drag to rotate")
                                            .font(.caption)
                                            .foregroundColor(Theme.textSecondary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(.ultraThinMaterial)
                                            .clipShape(Capsule())
                                            .overlay(
                                                Capsule()
                                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                            )
                                            .padding(.bottom, 24)
                                    }
                                }
                                
                                // Controls
                                HStack(spacing: 12) {
                                    SecondaryButton(title: "Reset View", icon: "arrow.counterclockwise", fullWidth: true) {
                                        // Reset logic
                                    }
                                    SecondaryButton(title: "AR View", icon: "viewfinder", fullWidth: true) {
                                        // AR logic
                                    }
                                }
                                .padding(16)
                            }
                        }
                        
                        // Dish Info
                        GlassCard {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(selectedDish.name)
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                        
                                        Text(selectedDetails.description)
                                            .font(.body)
                                            .foregroundColor(Theme.textSecondary)
                                            .lineLimit(3)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(selectedDetails.price)
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(Theme.primaryBlue)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Theme.primaryBlue.opacity(0.2))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Theme.primaryBlue.opacity(0.3), lineWidth: 1)
                                        )
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Ingredients")
                                        .font(.subheadline)
                                        .foregroundColor(Theme.textSecondary)
                                    
                                    FlowLayout(spacing: 8) {
                                        ForEach(selectedDetails.ingredients, id: \.self) { ingredient in
                                            Text(ingredient)
                                                .font(.caption)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Color.white.opacity(0.05))
                                                .clipShape(Capsule())
                                                .foregroundColor(Theme.textSecondary)
                                                .overlay(
                                                    Capsule()
                                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                                )
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Menu Carousel
                        VStack(alignment: .leading, spacing: 12) {
                            Text("More Dishes")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(0..<dishes.count, id: \.self) { index in
                                        let dish = dishes[index]
                                        let details = dishDetails[dish.id]!
                                        
                                        GlassCard(padding: 16) {
                                            VStack(spacing: 12) {
                                                ZStack {
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(LinearGradient(colors: [Theme.primaryBlue.opacity(0.2), Theme.primaryPurple.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                                        .frame(width: 80, height: 80)
                                                    
                                                    Text("🍽️")
                                                        .font(.largeTitle)
                                                }
                                                
                                                VStack(spacing: 4) {
                                                    Text(dish.name)
                                                        .font(.caption)
                                                        .fontWeight(.medium)
                                                        .foregroundColor(.white)
                                                        .multilineTextAlignment(.center)
                                                        .lineLimit(1)
                                                    
                                                    Text(details.price)
                                                        .font(.caption)
                                                        .foregroundColor(Theme.primaryBlue)
                                                }
                                            }
                                        }
                                        .frame(width: 160)
                                        .onTapGesture {
                                            withAnimation {
                                                selectedDishIndex = index
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}
