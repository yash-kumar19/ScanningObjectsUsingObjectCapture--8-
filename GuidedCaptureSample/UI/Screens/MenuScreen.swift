import SwiftUI

struct Category: Identifiable {
    let id: String
    let label: String
    let icon: String
    let count: Int
}

struct MenuScreen: View {
    // Callbacks
    var onBack: () -> Void
    var onDishClick: (String) -> Void
    
    // State
    @State private var selectedCategory = "all"
    
    // Data
    let categories = [
        Category(id: "all", label: "All", icon: "fork.knife", count: 24),
        Category(id: "appetizers", label: "Appetizers", icon: "cup.and.saucer.fill", count: 6),
        Category(id: "mains", label: "Mains", icon: "fork.knife.circle.fill", count: 10),
        Category(id: "seafood", label: "Seafood", icon: "fish.fill", count: 5),
        Category(id: "desserts", label: "Desserts", icon: "birthday.cake.fill", count: 3)
    ]
    
    let dishes = [
        Restaurant(id: "1", name: "Grilled Wagyu Steak", image: "https://images.unsplash.com/photo-1718939043329-b956bee61dbb", rating: 0, category: "Mains", dishes: 0), // Reusing Restaurant struct for simplicity or create new Dish struct
        Restaurant(id: "2", name: "Lobster Thermidor", image: "https://images.unsplash.com/photo-1580959375944-abd7e991f971", rating: 0, category: "Seafood", dishes: 0),
        Restaurant(id: "3", name: "Truffle Risotto", image: "https://images.unsplash.com/photo-1621996346565-e3dbc646d9a9", rating: 0, category: "Mains", dishes: 0),
        Restaurant(id: "4", name: "Chocolate Lava Cake", image: "https://images.unsplash.com/photo-1632996988763-7357605b6e6a", rating: 0, category: "Desserts", dishes: 0),
        Restaurant(id: "5", name: "Pan-Seared Salmon", image: "https://images.unsplash.com/photo-1580959375944-abd7e991f971", rating: 0, category: "Seafood", dishes: 0),
        Restaurant(id: "6", name: "Caesar Salad", image: "https://images.unsplash.com/photo-1718939043329-b956bee61dbb", rating: 0, category: "Appetizers", dishes: 0)
    ]
    
    // Additional data not in Restaurant struct
    let dishDetails: [String: (description: String, price: Double)] = [
        "1": ("Premium A5 Wagyu beef with truffle butter and seasonal vegetables", 85.00),
        "2": ("Fresh Atlantic lobster in creamy cognac sauce with parmesan crust", 65.00),
        "3": ("Creamy arborio rice with black truffle shavings and aged parmesan", 45.00),
        "4": ("Warm chocolate cake with molten center, vanilla ice cream", 18.00),
        "5": ("Wild-caught salmon with lemon butter sauce and asparagus", 52.00),
        "6": ("Classic Caesar with romaine, parmesan, croutons, and anchovy dressing", 16.00)
    ]
    
    var filteredDishes: [Restaurant] {
        if selectedCategory == "all" {
            return dishes
        }
        return dishes.filter { $0.category.lowercased() == selectedCategory.lowercased() || (selectedCategory == "mains" && $0.category == "Mains") } // Simple matching
    }
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            // Glows
            Circle()
                .fill(Theme.primaryBlue.opacity(0.15))
                .frame(width: 500, height: 500)
                .blur(radius: 120)
                .offset(x: -200, y: -300)
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 0) {
                    HStack(spacing: 16) {
                        Button(action: onBack) {
                            Image(systemName: "arrow.left")
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Menu")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Text("The Golden Fork")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                        
                        Spacer()
                    }
                    .padding(24)
                    
                    // Categories
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(categories) { category in
                                CategoryTab(
                                    label: category.label,
                                    count: category.count,
                                    isSelected: selectedCategory == category.id,
                                    onClick: {
                                        withAnimation {
                                            selectedCategory = category.id
                                        }
                                    },
                                    icon: category.icon
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                    }
                }
                .background(.ultraThinMaterial)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color.white.opacity(0.08)),
                    alignment: .bottom
                )
                
                // List
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredDishes) { dish in
                            if let details = dishDetails[dish.id] {
                                DishCard(
                                    id: dish.id,
                                    name: dish.name,
                                    description: details.description,
                                    price: details.price,
                                    category: dish.category,
                                    image: dish.image,
                                    onAddToCart: {
                                        print("Added \(dish.name) to cart")
                                    }
                                )
                                .onTapGesture {
                                    onDishClick(dish.id)
                                }
                            }
                        }
                    }
                    .padding(24)
                }
            }
        }
    }
}
