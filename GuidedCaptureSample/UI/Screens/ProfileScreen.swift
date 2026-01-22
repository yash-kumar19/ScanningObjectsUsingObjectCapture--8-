import SwiftUI

struct ProfileScreen: View {
    var onLogout: (() -> Void)?
    var onSwitchToOwner: (() -> Void)?
    
    @ObservedObject private var authManager = SupabaseManager.shared
    @State private var profile: Profile?
    @State private var isLoading = false
    @State private var showBecomeOwner = false
    
    // Combined User Data
    var userName: String {
        profile?.full_name ?? authManager.currentUser?.email?.components(separatedBy: "@").first?.capitalized ?? "User"
    }
    
    var userEmail: String {
        profile?.email ?? authManager.currentUser?.email ?? "Joined recently"
    }
    
    var userAvatar: String {
        profile?.avatar_url ?? "https://images.unsplash.com/photo-1704726135027-9c6f034cfa41?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=400"
    }
    
    var isOwner: Bool {
        profile?.role == "owner"
    }
    
    let menuItems: [ProfileMenuItem] = [
        ProfileMenuItem(icon: "calendar", label: "My Reservations", badge: "3", color: Color.fromHex("3B82F6")),
        ProfileMenuItem(icon: "heart.fill", label: "Favorite Restaurants", badge: "8", color: Color.fromHex("3B82F6")),
        ProfileMenuItem(icon: "creditcard", label: "Payment Methods", badge: nil, color: Color.fromHex("3B82F6")),
        ProfileMenuItem(icon: "bell.fill", label: "Notifications", badge: nil, color: Color.fromHex("3B82F6")),
        ProfileMenuItem(icon: "gearshape.fill", label: "Settings", badge: nil, color: Color.fromHex("3B82F6"))
    ]
    
    // Mock recent for now, can be real later
    let recentReservations = [
        RecentReservation(id: "1", restaurant: "The Golden Fork", date: "Nov 15, 2024", guests: 2, status: "Completed")
    ]
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .padding()
                    } else {
                        // User Profile Card
                        userProfileCard
                    }
                    
                    // Menu Items
                    menuItemsSection
                    
                    // Recent Reservations
                    recentReservationsSection
                    
                    // Owner Login Button - Hide if already owner
                    if !isOwner {
                        becomeOwnerButton
                    } else {
                        switchToOwnerButton
                    }
                    
                    // Logout Button
                    logoutButton
                    
                    // Bottom padding for tab bar
                    Color.clear.frame(height: 120)
                }
                .padding(.horizontal, 20)
            }
        }
        .onAppear {
            loadProfile()
            authManager.startPolling()
        }
        .onDisappear {
            authManager.stopPolling()
        }
        .onReceive(NotificationCenter.default.publisher(for: .supabaseDataDidUpdate)) { _ in
            loadProfile()
        }
    }
    
    private func loadProfile() {
        guard let userId = authManager.currentUser?.id else { return }
        // Don't set isLoading true on refresh to avoid flickering
        if profile == nil { isLoading = true }
        
        Task {
            do {
                let fetchedProfile = try await authManager.fetchProfile(userId: userId)
                await MainActor.run {
                    self.profile = fetchedProfile
                    self.isLoading = false
                }
            } catch {
                print("Error loading profile: \(error)")
                await MainActor.run { isLoading = false }
            }
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        HStack {
            Text("Profile")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
            
            Button(action: {}) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color.white.opacity(0.7))
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.05))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            }
        }
        .padding(.top, 60)
        .padding(.bottom, 4)
    }
    
    // MARK: - User Profile Card
    private var userProfileCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Avatar
                ZStack(alignment: .bottomTrailing) {
                    AsyncImage(url: URL(string: userAvatar)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                        default:
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.fromHex("1E293B"))
                                .frame(width: 80, height: 80)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.fromHex("3B82F6"), lineWidth: 2)
                    )
                    
                    // Online indicator
                    Circle()
                        .fill(Color.fromHex("22C55E"))
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .stroke(Color.fromHex("0B0F1A"), lineWidth: 2)
                        )
                        .offset(x: 4, y: 4)
                }
                
                // User Info
                VStack(alignment: .leading, spacing: 8) {
                    Text(userName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(userEmail)
                        .font(.system(size: 14))
                        .foregroundColor(Color.fromHex("94A3B8"))
                    
                    // Premium Badge
                    if isOwner {
                        Text("Restaurant Owner")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.fromHex("8B5CF6")) // Purple
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.fromHex("8B5CF6").opacity(0.2))
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.fromHex("8B5CF6").opacity(0.3), lineWidth: 1)
                            )
                    } else {
                        Text("Member")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.fromHex("3B82F6"))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.fromHex("3B82F6").opacity(0.2))
                            .cornerRadius(20)
                    }
                }
                
                Spacer()
            }
            
            // Stats (Mock for now)
            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.vertical, 4)
            
            HStack(spacing: 0) {
                StatView(value: "0", label: "Reservations")
                
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 1)
                
                StatView(value: "0", label: "Favorites")
                
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 1)
                
                StatView(value: "5.0", label: "Rating")
            }
        }
        .padding(20)
        .padding(20)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    // MARK: - Menu Items Section
    private var menuItemsSection: some View {
        VStack(spacing: 12) {
            ForEach(menuItems, id: \.label) { item in
                ProfileMenuItemView(item: item)
            }
        }
    }
    
    // MARK: - Recent Reservations Section
    private var recentReservationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Reservations")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            ForEach(recentReservations, id: \.id) { reservation in
                RecentReservationView(reservation: reservation)
            }
        }
    }
    
    // MARK: - Become Owner Button
    private var becomeOwnerButton: some View {
        Button(action: { showBecomeOwner = true }) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    LinearGradient(
                        colors: [Color(hex: "8B5CF6"), Color(hex: "3B82F6")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    Image(systemName: "storefront.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                    
                    // Sparkles
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "FDE047"))
                        .offset(x: 14, y: -14)
                }
                .frame(width: 56, height: 56)
                .cornerRadius(16)
                .shadow(color: Color(hex: "8B5CF6").opacity(0.3), radius: 8, x: 0, y: 4)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Become a\nRestaurant Owner")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(2)
                        
                        Text("New")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(hex: "8B5CF6").opacity(0.6))
                            .cornerRadius(8)
                            .offset(y: -8)
                    }
                    
                    Text("Upload 3D dishes and\ngrow your business")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "8B5CF6"))
            }
            .padding(16)
            .background(
                ZStack {
                    Color(hex: "1E293B").opacity(0.6)
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "8B5CF6").opacity(0.5), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
        }
        .fullScreenCover(isPresented: $showBecomeOwner) {
            BecomeOwnerScreen(
                onContinue: {
                    showBecomeOwner = false
                    // Update profile role
                    Task {
                        // Pass nil/empty for optional fields as this is just a role switch or handled inside Onboarding
                        // Actually, RestaurantOnboardingScreen handles the full update.
                        // So here we might just need to reload.
                        // But if we want to ensure role is set:
                        try? await authManager.updateProfile(
                             role: "owner",
                             restaurantName: nil,
                             logoURL: nil,
                             cuisine: nil,
                             address: nil,
                             phone: nil,
                             city: nil,
                             pincode: nil,
                             fssai: nil,
                             openingHours: nil,
                             bio: nil
                        )
                        // Reload
                        loadProfile()
                        onSwitchToOwner?()
                    }
                },
                onBack: {
                    showBecomeOwner = false
                }
            )
        }
    }
    
    // MARK: - Switch to Owner
    private var switchToOwnerButton: some View {
        Button(action: { onSwitchToOwner?() }) {
            Text("Switch to Owner View")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.fromHex("8B5CF6"))
                .cornerRadius(12)
        }
    }
    
    // MARK: - Logout Button
    private var logoutButton: some View {
        Button(action: { onLogout?() }) {
            HStack(spacing: 12) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 18))
                
                Text("Log Out")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(Color.fromHex("EF4444"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.fromHex("1E293B").opacity(0.6))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.fromHex("EF4444").opacity(0.2), lineWidth: 1)
            )
        }
    }
}

// MARK: - Stat View
struct StatView: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(Color.fromHex("94A3B8"))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Profile Menu Item View
struct ProfileMenuItemView: View {
    let item: ProfileMenuItem
    var body: some View {
        Button(action: {}) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: item.icon)
                    .font(.system(size: 18))
                    .foregroundColor(item.color)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                
                // Label
                Text(item.label)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Badge
                if let badge = item.badge {
                    Text(badge)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.fromHex("3B82F6"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.fromHex("3B82F6").opacity(0.2))
                        .cornerRadius(12)
                }
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(Color.white.opacity(0.4))
            }
            .padding(16)
            .background(Color.fromHex("1E293B").opacity(0.6))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Recent Reservation View
struct RecentReservationView: View {
    let reservation: RecentReservation
    var body: some View {
        Button(action: {}) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(reservation.restaurant)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(reservation.status)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.fromHex("22C55E"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.fromHex("22C55E").opacity(0.2))
                        .cornerRadius(12)
                }
                
                HStack(spacing: 8) {
                    Text(reservation.date)
                        .font(.system(size: 13))
                        .foregroundColor(Color.fromHex("94A3B8"))
                    
                    Text("•")
                        .foregroundColor(Color.fromHex("94A3B8"))
                    
                    Text("\(reservation.guests) guests")
                        .font(.system(size: 13))
                        .foregroundColor(Color.fromHex("94A3B8"))
                }
            }
            .padding(16)
            .background(Color.fromHex("1E293B").opacity(0.6))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Models
struct ProfileMenuItem {
    let icon: String
    let label: String
    let badge: String?
    let color: Color
}

struct RecentReservation {
    let id: String
    let restaurant: String
    let date: String
    let guests: Int
    let status: String
}

#Preview {
    ProfileScreen()
}
