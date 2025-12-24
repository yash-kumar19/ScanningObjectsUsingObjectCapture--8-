import SwiftUI

struct HomeView: View {
    @ObservedObject private var authManager = SupabaseManager.shared
    var onSwitchToOwner: () -> Void = {}
    var onLogout: () -> Void = {}
    
    @State private var selectedTab = 0

    @State private var isLoading = true
    @State private var showSignup = true
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Persistent Background
            Color.appBackground.ignoresSafeArea()
            
            // Show different content based on selected tab
            Group {
                if selectedTab == 0 {
                    // Home Tab
                    ScrollView {
                        VStack(spacing: 0) {
                            // Hero Section
                            heroSection
                                .skeleton(isLoading: isLoading)
                            
                            // Restaurants Section
                            restaurantsSection
                                .skeleton(isLoading: isLoading)
                            
                            // Why 3D Menus Section
                            why3DMenusSection
                            
                            // Bottom padding for tab bar
                            Color.clear.frame(height: 120)
                        }
                    }
                    .background(Color.appBackground)
                    .onAppear {
                        // Simulate loading
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                isLoading = false
                            }
                        }
                    }
                } else if selectedTab == 1 {
                    // Search Tab
                    SearchScreen(onRestaurantClick: { _ in })
                } else if selectedTab == 2 {
                    // Bookings Tab
                    MyReservationsScreen()
                } else {
                    // Profile Tab
                    if SupabaseManager.shared.isAuthenticated {
                        ProfileScreen(onLogout: onLogout, onSwitchToOwner: onSwitchToOwner)
                    } else {
                        if showSignup {
                            SignupScreen(
                                onSignupSuccess: {
                                    // After signup, switch back to login to let user sign in
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                        showSignup = false
                                    }
                                },
                                onBackToLogin: {
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                        showSignup = false
                                    }
                                }
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                        } else {
                            LoginScreen(
                                onLoginSuccess: {
                                    // Auth state change will trigger re-render
                                },
                                onSignup: {
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                        showSignup = true
                                    }
                                }
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                        }
                    }
                }
            }
            .id(selectedTab)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                removal: .opacity.combined(with: .scale(scale: 1.05))
            ))
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedTab)

            .ignoresSafeArea(.all, edges: .bottom)
            
            // Bottom Tab Bar
            BottomTabBar(selectedTab: $selectedTab)
        }
    }
    
    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(spacing: 16) {
            Text("NEXT-GEN DINING EXPERIENCE")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.brandPrimary)
                .tracking(1.5)
            
            Text("Explore Menus in 3D")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)
            
            Text("Scan, browse, and visualize dishes in\nimmersive 3D")
                .font(.system(size: 15))
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
            
            // 3D Model - seamless, no box
            Model3DView(modelName: "buger")
                .frame(width: 340, height: 300)
            
            // Scan QR Button
            Button(action: {}) {
                HStack(spacing: 12) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 24))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Scan Restaurant QR")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Instantly open the restaurant's 3D menu")
                            .font(.system(size: 13))
                            .foregroundColor(.textSecondary)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.cardBackground)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 20)
            
            // Scan QR Code button
            Button(action: {}) {
                Text("Scan QR Code")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        Color.brandPrimary
                            .shadow(.inner(color: Color.black.opacity(0), radius: 4))
                    )
                    .cornerRadius(12)
                    .shadow(color: Color.brandPrimary.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .padding(.vertical, 24)
    }
    
    // MARK: - Restaurants Section
    private var restaurantsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Explore Restaurants")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                Button(action: {}) {
                    Text("See All")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.brandPrimary)
                }
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    RestaurantCard(
                        id: "1",
                        name: "The Grand Bistro",
                        image: "https://images.unsplash.com/photo-1744776411221-702f2848b0b2",
                        rating: 4.8,
                        cuisine: "Fine Dining",
                        location: "Downtown",
                        priceRange: "$$$",
                        onClick: {}
                    )
                    
                    RestaurantCard(
                        id: "2",
                        name: "Bella Italia",
                        image: "https://images.unsplash.com/photo-1518003184446-383eb111b1e3",
                        rating: 4.6,
                        cuisine: "Italian",
                        location: "Midtown",
                        priceRange: "$$",
                        onClick: {}
                    )
                    
                    RestaurantCard(
                        id: "3",
                        name: "Sushi Master",
                        image: "https://images.unsplash.com/photo-1725122194872-ace87e5a1a8d",
                        rating: 4.9,
                        cuisine: "Japanese",
                        location: "West End",
                        priceRange: "$$",
                        onClick: {}
                    )
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 24)
    }
    
    // MARK: - Why 3D Menus Section
    private var why3DMenusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Why 3D Menus?")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.textPrimary)
                .padding(.horizontal, 20)
                .skeleton(isLoading: isLoading)
            
            VStack(spacing: 12) {
                FeatureCardV2(
                    icon: "cube.fill",
                    iconColor: Color(hex: "3B82F6"),
                    iconBackground: LinearGradient(
                        colors: [Color(hex: "3B82F6"), Color(hex: "2563EB")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    title: "3D Food Models",
                    description: "View dishes in stunning interactive 3D"
                )
                
                FeatureCardV2(
                    icon: "sparkles",
                    iconColor: Color(hex: "8B5CF6"),
                    iconBackground: LinearGradient(
                        colors: [Color(hex: "8B5CF6"), Color(hex: "7C3AED")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    title: "AR Preview",
                    description: "Place dishes on your table with ARKit/ARCore"
                )
                
                FeatureCardV2(
                    icon: "photo.fill",
                    iconColor: Color(hex: "3B82F6"),
                    iconBackground: LinearGradient(
                        colors: [Color(hex: "3B82F6"), Color(hex: "2563EB")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    title: "HD Photos",
                    description: "See high-quality images of each dish"
                )
            }
            .padding(.horizontal, 20)
            .skeleton(isLoading: isLoading)
            
            // Login prompt
            VStack(spacing: 8) {
                Text("Are you a restaurant owner?")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "9CA3AF"))
                
                LoginButton()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color(hex: "1A1F2E").opacity(0.5))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hex: "3B82F6").opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .skeleton(isLoading: isLoading)
        }
        .padding(.vertical, 24)
    }
}

#Preview {
    HomeView()
}
