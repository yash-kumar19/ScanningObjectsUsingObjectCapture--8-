import SwiftUI

struct RestaurantDetailsScreenV2: View {
    // Callbacks
    var onBack: () -> Void
    var onViewFullMenu: () -> Void
    var onDishClick: (String) -> Void
    var onMakeReservation: () -> Void
    
    // State
    @State private var selectedCategory: String = "popular"
    
    // Data
    let restaurant = (
        name: "The Golden Fork",
        image: "https://images.unsplash.com/photo-1744776411214-31209006a0f6",
        rating: 4.8,
        cuisine: "Fine Dining",
        location: "123 Luxury Ave, Downtown",
        phone: "+1 (555) 123-4567",
        description: "Experience culinary excellence in an elegant atmosphere. Our award-winning chefs create innovative dishes using the finest seasonal ingredients.",
        openNow: true,
        hours: "11:00 AM - 10:00 PM"
    )
    
    let categories = [
        (id: "popular", label: "Popular", count: 8, icon: "star.fill"),
        (id: "appetizers", label: "Appetizers", count: 6, icon: "carrot.fill"),
        (id: "mains", label: "Mains", count: 10, icon: "fork.knife"),
        (id: "desserts", label: "Desserts", count: 4, icon: "birthday.cake.fill")
    ]
    
    let dishes = [
        (
            id: "1",
            name: "Grilled Wagyu Steak",
            description: "Premium A5 Wagyu beef with truffle butter",
            price: 85.00,
            category: "Mains",
            image: "https://images.unsplash.com/photo-1718939043329-b956bee61dbb"
        ),
        (
            id: "2",
            name: "Lobster Thermidor",
            description: "Fresh Atlantic lobster in cognac sauce",
            price: 65.00,
            category: "Seafood",
            image: "https://images.unsplash.com/photo-1580959375944-abd7e991f971"
        ),
        (
            id: "3",
            name: "Truffle Risotto",
            description: "Creamy arborio rice with black truffle",
            price: 45.00,
            category: "Mains",
            image: "https://images.unsplash.com/photo-1621996346565-e3dbc646d9a9"
        )
    ]
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Header Image
                    ZStack(alignment: .top) {
                        AsyncImage(url: URL(string: restaurant.image)) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Color.gray.opacity(0.3)
                            }
                        }
                        .frame(height: 288) // h-72 approx
                        .clipped()
                        .overlay(
                            LinearGradient(colors: [.clear, Theme.background.opacity(0.6), Theme.background], startPoint: .center, endPoint: .bottom)
                        )
                        
                        // Glow Overlay
                        LinearGradient(colors: [Theme.primaryBlue.opacity(0.1), .clear], startPoint: .top, endPoint: .bottom)
                            .frame(height: 100)
                            .offset(y: -50)
                            .blur(radius: 40)
                        
                        // Top Controls
                        HStack {
                            Button(action: onBack) {
                                Image(systemName: "arrow.left")
                                    .foregroundColor(.white)
                                    .frame(width: 48, height: 48)
                                    .background(Color.black.opacity(0.6))
                                    .cornerRadius(20)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                    )
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 8) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                    .font(.caption)
                                Text(String(format: "%.1f", restaurant.rating))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 60)
                    }
                    
                    VStack(spacing: 24) {
                        // Info Card
                        GlassCard {
                            VStack(alignment: .leading, spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(restaurant.name)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    Text(restaurant.cuisine)
                                        .font(.subheadline)
                                        .foregroundColor(Theme.textSecondary)
                                }
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "mappin.and.ellipse")
                                            .foregroundColor(Theme.primaryBlue)
                                        Text(restaurant.location)
                                            .font(.body)
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                    
                                    HStack(spacing: 12) {
                                        Image(systemName: "clock")
                                            .foregroundColor(Theme.primaryBlue)
                                        HStack(spacing: 8) {
                                            Text(restaurant.hours)
                                                .font(.body)
                                                .foregroundColor(Theme.textSecondary)
                                            
                                            if restaurant.openNow {
                                                Text("Open Now")
                                                    .font(.caption)
                                                    .foregroundColor(.green)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Color.green.opacity(0.2))
                                                    .cornerRadius(12)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                                    )
                                            }
                                        }
                                    }
                                    
                                    HStack(spacing: 12) {
                                        Image(systemName: "phone")
                                            .foregroundColor(Theme.primaryBlue)
                                        Text(restaurant.phone)
                                            .font(.body)
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                }
                                
                                Divider().background(Color.white.opacity(0.08))
                                
                                Text(restaurant.description)
                                    .font(.body)
                                    .foregroundColor(Theme.textSecondary)
                                    .lineSpacing(4)
                            }
                        }
                        .offset(y: -48)
                        .padding(.bottom, -48)
                        .shadow(color: Theme.primaryBlue.opacity(0.2), radius: 32, x: 0, y: 8)
                        .shadow(color: Theme.primaryPurple.opacity(0.1), radius: 60, x: 0, y: 0)
                        
                        // Categories
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(categories, id: \.id) { category in
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
                        }
                        
                        // Dishes
                        VStack(spacing: 16) {
                            ForEach(dishes, id: \.id) { dish in
                                DishCard(
                                    id: dish.id,
                                    name: dish.name,
                                    description: dish.description,
                                    price: dish.price,
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
                        .padding(.horizontal, 24)
                        
                        // Actions
                        VStack(spacing: 12) {
                            SecondaryButton(title: "View Full Menu", fullWidth: true, action: onViewFullMenu)
                            PrimaryButton(title: "Make a Reservation", fullWidth: true, action: onMakeReservation)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
        }
    }
}
