import SwiftUI

struct SearchScreen: View {
    var onRestaurantClick: (Profile) -> Void // Changed to accept Profile
    
    @State private var searchQuery: String = ""
    @State private var selectedCuisine: String = "all"
    @State private var restaurants: [Profile] = []
    @State private var isLoading = false
    
    let cuisines = [
        (id: "all", label: "All", icon: "sparkles"),
        (id: "italian", label: "Italian", icon: "fork.knife"),
        (id: "asian", label: "Asian", icon: "cup.and.saucer"),
        (id: "healthy", label: "Healthy", icon: "leaf")
    ]
    
    var filteredRestaurants: [Profile] {
        if searchQuery.isEmpty {
            return restaurants
        } else {
            return restaurants.filter {
                ($0.restaurant_name ?? "").localizedCaseInsensitiveContains(searchQuery)
            }
        }
    }
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Discover")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Find your perfect dining experience")
                            .font(.system(size: 15))
                            .foregroundColor(Color.fromHex("94A3B8"))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                    .padding(.bottom, 20)
                    
                    // Search Bar - Use existing SearchInput component
                    SearchInput(
                        text: $searchQuery,
                        placeholder: "Search restaurants..."
                    )
                    .padding(.horizontal, 20)
                    
                    // Filter Chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(cuisines, id: \.id) { cuisine in
                                FilterChip(
                                    label: cuisine.label,
                                    isSelected: selectedCuisine == cuisine.id,
                                    action: { selectedCuisine = cuisine.id },
                                    icon: cuisine.icon
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 20)
                    
                    if isLoading {
                        ProgressView().tint(.white).padding(40)
                    } else if filteredRestaurants.isEmpty {
                         Text(restaurants.isEmpty ? "No restaurants found." : "No matches found.")
                             .foregroundColor(.gray)
                             .padding(40)
                    } else {
                        // Restaurant List
                        VStack(spacing: 16) {
                            ForEach(filteredRestaurants) { restaurant in
                                Button(action: {
                                    onRestaurantClick(restaurant)
                                }) {
                                    DiscoverRestaurantCard(
                                        name: restaurant.restaurant_name ?? "Unnamed",
                                        logoURL: restaurant.logo_url ?? restaurant.avatar_url,
                                        rating: 4.8, // Mock
                                        cuisine: restaurant.cuisine ?? "Fine Dining",
                                        location: restaurant.city ?? "Downtown",
                                        priceRange: "$$$" // Mock
                                    )
                                }
                                .buttonStyle(DiscoverScaleButtonStyle())
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 120)
                    }
                }
            }
        }
        .onAppear {
            loadData()
        }
    }
    
    private func loadData() {
        if restaurants.isEmpty { isLoading = true }
        Task {
            do {
                let items = try await SupabaseManager.shared.fetchRestaurants()
                await MainActor.run {
                    self.restaurants = items
                    self.isLoading = false
                }
            } catch {
                print("Error fetching restaurants: \(error)")
                await MainActor.run { self.isLoading = false }
            }
        }
    }
}

// Restaurant Card for Discover Screen
struct DiscoverRestaurantCard: View {
    let name: String
    let logoURL: String?
    let rating: Double
    let cuisine: String
    let location: String
    let priceRange: String
    

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image
            ZStack(alignment: .topTrailing) {
                // Restaurant image with fallback gradient
                AsyncImage(url: URL(string: logoURL ?? "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800&h=600&fit=crop")) { phase in
                    switch phase {
                    case .empty:
                        // Loading placeholder
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.fromHex("1E293B"),
                                        Color.fromHex("0F172A")
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 180)
                            .clipped()
                    case .failure:
                        // Fallback gradient on error
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.fromHex("1E293B"),
                                        Color.fromHex("0F172A")
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(height: 180)
                
                // Overlays
                HStack {
                    // Price Range Badge
                    Text(priceRange)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                        .padding(12)
                    
                    Spacer()
                    
                    // Rating Badge
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color.fromHex("FCD34D"))
                        
                        Text(String(format: "%.1f", rating))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                    .padding(12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .cornerRadius(16)
            
            // Info Section
            VStack(alignment: .leading, spacing: 8) {
                Text(name)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Text(cuisine)
                    .font(.system(size: 14))
                    .foregroundColor(Color.fromHex("94A3B8"))
                
                HStack(spacing: 4) {
                    Image(systemName: "mappin")
                        .font(.system(size: 13))
                        .foregroundColor(Color.fromHex("64748B"))
                    
                    Text(location)
                        .font(.system(size: 13))
                        .foregroundColor(Color.fromHex("64748B"))
                }
                
                // View Menu Button
                DiscoverViewMenuButton()
                    .padding(.top, 4)
            }
            .padding(16)
            .background(Color.fromHex("1E293B"))
            .cornerRadius(16)
        }
        .background(Color.fromHex("1E293B"))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.fromHex("334155"), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

struct DiscoverViewMenuButton: View {
    var body: some View {
        Text("View Menu")
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [
                        Color.fromHex("3B82F6"),
                        Color.fromHex("2563EB")
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: Color.fromHex("3B82F6").opacity(0.4), radius: 8, x: 0, y: 4)
    }
}

// Helper function removed as we now use real data


struct DiscoverScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    SearchScreen(onRestaurantClick: { _ in })
}
