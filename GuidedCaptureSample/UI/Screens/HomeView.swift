import SwiftUI

struct HomeView: View {
    @ObservedObject private var authManager = SupabaseManager.shared
    @ObservedObject private var deepLinkHandler = DeepLinkHandler.shared
    
    var onSwitchToOwner: () -> Void = {}
    var onLogout: () -> Void = {}
    
    @State private var selectedTab = 0
    @State private var selectedRestaurant: Restaurant? // Track selected restaurant
    @State private var selectedRestaurantId: String? // Track restaurant ID from deep link
    @State private var showQRScanner = false // Track QR scanner presentation

    // Order flow
    @State private var showCustomerInfoSheet = false
    @State private var pendingOrderId: String? = nil
    @State private var pendingConfirmState: OrderConfirmState? = nil
    @State private var customerNamePrefill: String = ""
    @State private var showOrdersDetailsGlobal = false

    @State private var isLoading = true
    @State private var showOwnerLogin = false
    @State private var restaurants: [Restaurant] = []
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.background.ignoresSafeArea()
            
            // Show different content based on selected tab
            Group {
                if selectedTab == 0 {
                    // Home Tab
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            // Hero Section
                            heroSection
                                .skeleton(isLoading: isLoading)
                            
                            // Restaurants Section
                             // Since we don't have real data wired for the Home Tab widgets yet (except Search),
                             // we leave this as is or we can wire it later.
                             // For now, let's keep it mock or static to avoid breaking visuals.
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
                        loadHomeData()
                    }
                } else if selectedTab == 1 {
                    // Search Tab
                    SearchScreen(onRestaurantClick: { restaurant in
                         withAnimation {
                             selectedRestaurant = restaurant
                         }
                    })
                } else if selectedTab == 2 {
                    // Cart Tab
                    CartScreen(onCheckout: {
                        // Pre-fill name from logged-in profile's full_name (never email)
                        if let profile = SupabaseManager.shared.currentUser {
                            Task {
                                let name = (try? await fetchProfileFullName(userId: profile.id)) ?? ""
                                await MainActor.run {
                                    customerNamePrefill = name
                                    showCustomerInfoSheet = true
                                }
                            }
                        } else {
                            customerNamePrefill = ""
                            showCustomerInfoSheet = true
                        }
                    },
                    hasActiveOrder: pendingOrderId != nil,
                    onViewOrders: {
                        showOrdersDetailsGlobal = true
                    })
                } else {
                    // Restaurant Portal Tab (Owners only)
                    RestaurantPortalView(
                        onLogin: {
                            SupabaseManager.shared.loginIntent = .owner
                            showOwnerLogin = true
                        },
                        onSignup: {
                            SupabaseManager.shared.loginIntent = .owner
                            showOwnerLogin = true
                        },
                        onGoToDashboard: {
                            onSwitchToOwner()
                        }
                    )
                }
            }
            .id(selectedTab) // Simple transitions
            
            // Restaurant Detail Overlay
            if let restaurant = selectedRestaurant {
                RestaurantDetailsScreenV2(
                    onBack: {
                        withAnimation {
                            selectedRestaurant = nil
                        }
                    },
                    onDishClick: { dishId in
                        print("Clicked dish: \(dishId)")
                    },
                    restaurant: restaurant
                )
                .transition(.move(edge: .trailing))
                .zIndex(100)
            }
            
            // Bottom Tab Bar (Hide when detail is shown)
            if selectedRestaurant == nil {
                Color.clear.frame(height: 0) // Spacer
                BottomTabBar(selectedTab: $selectedTab)
            }
        }
        .onReceive(deepLinkHandler.$pendingRestaurantId) { restaurantId in
            guard let restaurantId = restaurantId else { return }
            
            print("🔗 [HomeView] Deep link received for restaurant: \(restaurantId)")
            
            // Navigate to restaurant by ID
            Task {
                await navigateToRestaurant(restaurantId: restaurantId)
                
                // Clear pending navigation
                await MainActor.run {
                    deepLinkHandler.clearPendingNavigation()
                }
            }
        }
        .alert("Error", isPresented: $deepLinkHandler.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(deepLinkHandler.errorMessage)
        }
        // Order flow modals — use item: binding to guarantee non-nil content (prevents black screen)
        .sheet(isPresented: $showCustomerInfoSheet, onDismiss: {
            // fullScreenCover(item:) auto-triggers when pendingConfirmState is set
        }) {
            CustomerInfoSheet(
                prefillName: customerNamePrefill,
                onConfirm: { name, e164Phone, notes in
                    pendingConfirmState = OrderConfirmState(
                        name: name, phone: e164Phone, notes: notes,
                        restaurantId: CartManager.shared.restaurantId ?? ""
                    )
                    showCustomerInfoSheet = false
                }
            )
        }
        // fullScreenCover(item:) — content guaranteed non-nil, no black screen
        .fullScreenCover(item: $pendingConfirmState) { state in
            OrderConfirmationScreen(
                restaurantId: state.restaurantId,
                customerName: state.name,
                customerPhone: state.phone,
                specialNotes: state.notes,
                paymentMethod: .cash,
                onOrderPlaced: { orderId in
                    pendingOrderId = orderId
                    pendingConfirmState = nil  // dismisses this cover
                    showOrdersDetailsGlobal = true
                },
                onDismiss: {
                    pendingOrderId = nil
                    pendingConfirmState = nil
                }
            )
        }
        .fullScreenCover(isPresented: $showOrdersDetailsGlobal) {
            OrdersDetailsScreen()
        }
        .fullScreenCover(isPresented: $showQRScanner) {
            QRScannerView(
                onScanSuccess: { scannedURL in
                    handleScannedQR(url: scannedURL)
                },
                onDismiss: {
                    showQRScanner = false
                }
            )
        }
        .fullScreenCover(isPresented: $showOwnerLogin) {
            OwnerLoginScreen(
                onLogin: {
                    // RootView will detect auth change and switch flow
                    showOwnerLogin = false
                },
                onBack: {
                    SupabaseManager.shared.loginIntent = .none
                    showOwnerLogin = false
                }
            )
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
            Button(action: {
                showQRScanner = true
            }) {
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
            Button(action: {
                showQRScanner = true
            }) {
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
                
                Button(action: {
                    withAnimation {
                        selectedTab = 1
                    }
                }) {
                    Text("See All")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.brandPrimary)
                }
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    if restaurants.isEmpty {
                        RestaurantCard(
                            id: "placeholder",
                            name: "No Active Restaurants",
                            image: "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4",
                            rating: 5.0,
                            cuisine: "Browse Menu",
                            location: "Online",
                            priceRange: "$",
                            onClick: {}
                        )
                    } else {
                        ForEach(restaurants) { rest in
                            RestaurantCard(
                                id: rest.id,
                                name: rest.name,
                                image: rest.logo_url ?? "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4",
                                rating: 4.8,
                                cuisine: rest.cuisine_type ?? "Fine Dining",
                                location: rest.city ?? "Downtown",
                                priceRange: "$$$",
                                onClick: {
                                    withAnimation {
                                        selectedRestaurant = rest
                                    }
                                }
                            )
                        }
                    }
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
                
                LoginButton(action: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        selectedTab = 3
                    }
                })
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
    
    // MARK: - Deep Link Navigation
    
    /// Navigate to restaurant menu by ID (from deep link)
    @MainActor
    private func navigateToRestaurant(restaurantId: String) async {
        do {
            // Fetch restaurant profile using public API
            let profile = try await SupabaseManager.shared.fetchPublicRestaurant(restaurantId: restaurantId)
            
            // Present restaurant details screen
            withAnimation {
                selectedRestaurant = profile
            }
            
            print("✅ [HomeView] Navigated to restaurant: \(profile.name)")
        } catch {
            print("❌ [HomeView] Failed to load restaurant: \(error.localizedDescription)")
            
            // Show error via DeepLinkHandler
            deepLinkHandler.errorMessage = "Unable to load restaurant. Please try again."
            deepLinkHandler.showError = true
        }
    }
    
    /// Handle scanned QR code URL
    @MainActor
    private func handleScannedQR(url: String) {
        print("🔍 [HomeView] Scanned QR code: \(url)")
        
        // Dismiss scanner
        showQRScanner = false
        
        // Parse URL
        guard let qrURL = URL(string: url) else {
            deepLinkHandler.errorMessage = "Invalid QR code format"
            deepLinkHandler.showError = true
            return
        }
        
        // Let DeepLinkHandler process the URL
        let handled = deepLinkHandler.handleURL(qrURL)
        
        if !handled {
            deepLinkHandler.errorMessage = "This QR code is not a valid restaurant menu link"
            deepLinkHandler.showError = true
        }
    }
    
    /// Load dynamic active restaurants from Supabase
    private func loadHomeData() {
        isLoading = true
        Task {
            do {
                let items = try await SupabaseManager.shared.fetchRestaurants()
                await MainActor.run {
                    self.restaurants = items
                    withAnimation {
                        self.isLoading = false
                    }
                }
            } catch {
                print("❌ Error loading restaurants: \(error)")
                await MainActor.run {
                    withAnimation {
                        self.isLoading = false
                    }
                }
            }
        }
    }
}

#Preview {
    HomeView()
}

// MARK: - Order Confirm State

struct OrderConfirmState: Identifiable {
    let id = UUID()  // Identifiable — required for fullScreenCover(item:)
    let name: String
    let phone: String
    let notes: String?
    let restaurantId: String
}

/// Lightweight wrapper so a plain String order ID can drive fullScreenCover(item:)
struct OrderIdWrapper: Identifiable {
    let id: String  // the actual order UUID string
}

// MARK: - Profile Full Name Lookup

/// Fetch the user's full_name from the profiles table (never falls back to email)
func fetchProfileFullName(userId: String) async throws -> String {
    let token = try await SupabaseManager.shared.getValidAccessTokenOrRefresh()
    let url = SupabaseConfig.databaseURL.appendingPathComponent("profiles")
        .appending(queryItems: [
            URLQueryItem(name: "id", value: "eq.\(userId)"),
            URLQueryItem(name: "select", value: "full_name")
        ])
    var req = URLRequest(url: url)
    req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    req.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
    let (data, _) = try await URLSession.shared.data(for: req)
    struct Row: Decodable { let full_name: String? }
    let rows = try JSONDecoder().decode([Row].self, from: data)
    return rows.first?.full_name ?? ""
}
