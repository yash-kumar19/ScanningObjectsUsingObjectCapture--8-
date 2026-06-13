import SwiftUI

struct SearchScreen: View {
    var onRestaurantClick: (Restaurant) -> Void // Changed to accept Restaurant
    
    @State private var searchQuery: String = ""
    @State private var selectedCuisine: String = "all"
    @State private var restaurants: [Restaurant] = []
    @State private var isLoading = false
    
    let cuisines = [
        (id: "all", label: "All", icon: "sparkles"),
        (id: "italian", label: "Italian", icon: "fork.knife"),
        (id: "asian", label: "Asian", icon: "cup.and.saucer"),
        (id: "healthy", label: "Healthy", icon: "leaf")
    ]
    
    var filteredRestaurants: [Restaurant] {
        var result = restaurants
        
        // Filter by Cuisine
        if selectedCuisine != "all" {
            result = result.filter { ($0.cuisine_type ?? "").lowercased() == selectedCuisine.lowercased() }
        }
        
        // Filter by Search Query
        if !searchQuery.isEmpty {
            result = result.filter {
                ($0.name).localizedCaseInsensitiveContains(searchQuery)
            }
        }
        
        return result
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
                            .foregroundColor(Color(hex: "94A3B8"))
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
                        LazyVStack(spacing: 16) {
                            ForEach(filteredRestaurants) { restaurant in
                                DiscoverRestaurantCard(
                                    name: restaurant.name,
                                    logoURL: restaurant.logo_url,
                                    rating: 4.8, // Mock
                                    cuisine: restaurant.cuisine_type ?? "Fine Dining",
                                    location: restaurant.city ?? "Downtown",
                                    priceRange: "$$$", // Mock
                                    onViewMenu: {
                                        onRestaurantClick(restaurant)
                                    }
                                )
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
    let onViewMenu: () -> Void
    

    var body: some View {
        Button(action: onViewMenu) {
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
                                            Color(hex: "1E293B"),
                                            Color(hex: "0F172A")
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
                                            Color(hex: "1E293B"),
                                            Color(hex: "0F172A")
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
                            .foregroundColor(Color(hex: "FCD34D"))
                            
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
                        .foregroundColor(Color(hex: "94A3B8"))
                    
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "64748B"))
                        
                        Text(location)
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "64748B"))
                    }
                    
                    // View Menu Button - Flattened, purely visual
                    DiscoverViewMenuButton()
                        .allowsHitTesting(false)
                        .padding(.top, 4)
                }
                .padding(16)
                .background(Color(hex: "1E293B"))
                .cornerRadius(16)
            }
            .background(Color(hex: "1E293B"))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hex: "334155"), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        }
        .contentShape(Rectangle())
        .buttonStyle(.plain)
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
                        Color(hex: "3B82F6"),
                        Color(hex: "2563EB")
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: Color(hex: "3B82F6").opacity(0.4), radius: 8, x: 0, y: 4)
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
