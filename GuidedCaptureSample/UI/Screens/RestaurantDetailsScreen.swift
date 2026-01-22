import SwiftUI

struct RestaurantDetailsScreenV2: View {
    // Callbacks
    var onBack: () -> Void
    var onViewFullMenu: () -> Void
    var onDishClick: (String) -> Void
    
    // Data
    let restaurantProfile: Profile
    @State private var liveProfile: Profile? // For real-time updates
    
    // State
    @State private var selectedCategory: String = "Popular"
    @State private var showBookingSheet = false
    @State private var showSuccessAlert = false
    
    @State private var dishes: [Dish] = []
    @State private var selectedDishForAR: Dish?
    @State private var showARView = false
    
    // 3D Preview State (inline pattern from OwnerMenuScreen)
    @StateObject private var downloader = ModelDownloader()
    @State private var show3DPreview = false
    @State private var selected3DModelURL: URL?
    @State private var local3DModelURL: URL?
    @State private var download3DError: String?
    
    // Polling handled in .task
    
    // Dynamic Categories
    var categories: [String] {
        var cats = ["Popular"]
        let dishCats = Set(dishes.map { $0.category }).sorted()
        cats.append(contentsOf: dishCats)
        return cats
    }
    
    // Use live profile if available, otherwise fall back to initial
    var displayedProfile: Profile {
        liveProfile ?? restaurantProfile
    }
    
    // Data accessors
    var restaurantName: String { displayedProfile.restaurant_name ?? "Restaurant" }
    var location: String { displayedProfile.address ?? "Downtown" }
    var cuisine: String { displayedProfile.cuisine ?? "Fine Dining" }
    var phone: String { displayedProfile.phone ?? "+1 (555) 000-0000" }
    
    // Using real data fields from Profile
    var hours: String { displayedProfile.opening_hours ?? "11:00 AM - 10:00 PM" }
    var description: String { displayedProfile.bio ?? "Experience culinary excellence in our establishment. Owned by \(displayedProfile.full_name ?? "our chef")." }
    
    var filteredDishes: [Dish] {
        if selectedCategory == "Popular" {
            // For popular, showing first 5 for now or featured if we had that flag
            return Array(dishes.prefix(5))
        } else {
            return dishes.filter { $0.category.localizedCaseInsensitiveContains(selectedCategory) }
        }
    }
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    heroHeader
                    infoCard
                    categoryFilter
                    dishList
                }
            }
            .ignoresSafeArea()
            
            bottomActionButtons
        }
        .sheet(isPresented: $showBookingSheet) {
            BookingSheet(
                ownerId: displayedProfile.id,
                restaurantName: displayedProfile.restaurant_name ?? "Restaurant",
                onDismiss: { showBookingSheet = false },
                onSuccess: { showSuccessAlert = true },
                isPresented: $showBookingSheet
            )
        }
        .alert("Booking Confirmed!", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your table has been reserved successfully.")
        }
        .fullScreenCover(isPresented: $show3DPreview) {
            // ✅ Inline 3D Preview (same pattern as OwnerMenuScreen)
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let localURL = local3DModelURL {
                    // Show the model using QuickLook
                    ZStack(alignment: .topTrailing) {
                        ModelView(modelFile: localURL, endCaptureCallback: {
                            show3DPreview = false
                        })
                        .ignoresSafeArea()
                        
                        // Close Button
                        Button(action: { show3DPreview = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                        }
                        .padding(24)
                    }
                } else if downloader.isDownloading {
                    // Show download progress
                    VStack(spacing: 20) {
                        ProgressView(value: downloader.downloadProgress)
                            .progressViewStyle(.linear)
                            .tint(Color(hex: "3B82F6"))
                            .frame(width: 200)
                        
                        Text("Downloading model...")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("\(Int(downloader.downloadProgress * 100))%")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        Button(action: { show3DPreview = false }) {
                            Text("Cancel")
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color(hex: "1E293B"))
                                .cornerRadius(12)
                        }
                    }
                } else if let error = download3DError {
                    // Show error
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.yellow)
                        
                        Text("Download Failed")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button(action: { show3DPreview = false }) {
                            Text("Close")
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color(hex: "3B82F6"))
                                .cornerRadius(12)
                        }
                    }
                }
            }
            .task {
                // ✅ Best Practice: Read selected3DModelURL DIRECTLY from parent scope
                print("🔍 3D Preview sheet task started")
                print("🔍 selected3DModelURL: \(selected3DModelURL?.absoluteString ?? "nil")")
                
                guard let url = selected3DModelURL else {
                    print("❌ No URL in selected3DModelURL")
                    download3DError = "No model URL provided"
                    return
                }
                
                // If it's already a local file URL, use it directly
                if url.isFileURL {
                    local3DModelURL = url
                    return
                }
                
                // Otherwise, download from remote URL
                do {
                    let localURL = try await downloader.downloadModel(from: url)
                    
                    // 🔥 Give filesystem a moment to settle before Quick Look
                    try await Task.sleep(nanoseconds: 300_000_000) // 0.3s
                    
                    await MainActor.run {
                        local3DModelURL = localURL
                    }
                } catch {
                    await MainActor.run {
                        download3DError = error.localizedDescription
                    }
                }
            }
        }
        .task {
            // Initial load
            await loadData()
            
            // Polling loop
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5 * 1_000_000_000) // 5 seconds
                await loadData()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var heroHeader: some View {
        ZStack(alignment: .top) {
            AsyncImage(url: URL(string: displayedProfile.logo_url ?? displayedProfile.avatar_url ?? "https://images.unsplash.com/photo-1559339352-11d035aa65de")) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                case .failure, .empty:
                    Rectangle().fill(Color(hex: "1e293b"))
                @unknown default:
                    Rectangle().fill(Color(hex: "1e293b"))
                }
            }
            .frame(height: 280)
            .clipped()
            .overlay(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.3)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            // Top Nav
            HStack {
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Circle().fill(Color.black.opacity(0.6)))
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 12))
                    Text("4.8")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.black.opacity(0.6)))
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
        }
    }
    
    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Title & Tags
            VStack(alignment: .leading, spacing: 6) {
                Text(restaurantName)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                
                Text(cuisine)
                    .font(.system(size: 15))
                    .foregroundColor(Color.white.opacity(0.7))
            }
            
            // Meta Info (Address, Time, Phone)
            VStack(alignment: .leading, spacing: 14) {
                InfoRow(icon: "mappin.and.ellipse", text: location)
                
                HStack(spacing: 12) {
                    Image(systemName: "clock")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "3b82f6"))
                        .frame(width: 20)
                    
                    HStack(spacing: 8) {
                        Text(hours)
                            .font(.system(size: 15))
                            .foregroundColor(Color.white.opacity(0.8))
                        
                        Text("Open Now")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: "22c55e"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(hex: "22c55e").opacity(0.15))
                            .cornerRadius(6)
                    }
                }
                
                InfoRow(icon: "phone", text: phone)
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            Text(description)
                .font(.system(size: 14))
                .foregroundColor(Color.white.opacity(0.6))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .background(Color(hex: "1e293b"))
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .offset(y: -40)
        .padding(.bottom, -20)
    }
    
    private var categoryFilter: some View {
        Group {
            if !dishes.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(categories, id: \.self) { category in
                            Button(action: {
                                withAnimation {
                                    selectedCategory = category
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Text(category)
                                        .font(.system(size: 15, weight: .medium))
                                    
                                    let count = category == "Popular" ? min(5, dishes.count) : dishes.filter { $0.category == category }.count
                                    Text("\(count)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(selectedCategory == category ? .white : Color.white.opacity(0.5))
                                        .padding(6)
                                        .background(
                                            Circle().fill(selectedCategory == category ? Color.white.opacity(0.2) : Color.white.opacity(0.05))
                                        )
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    selectedCategory == category ? Color(hex: "2563eb") : Color(hex: "1e293b")
                                )
                                .foregroundColor(
                                    selectedCategory == category ? .white : Color.white.opacity(0.6)
                                )
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(
                                            selectedCategory == category ? Color.blue : Color.white.opacity(0.1),
                                            lineWidth: 1
                                        )
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 10)
            }
        }
    }
    
    private var dishList: some View {
        Group {
            if dishes.isEmpty {
                 VStack(spacing: 16) {
                    Image(systemName: "fork.knife.circle")
                        .font(.system(size: 48))
                        .foregroundColor(Color.white.opacity(0.3))
                    Text("No dishes available")
                        .foregroundColor(Color.white.opacity(0.6))
                }
                .padding(.vertical, 40)
            } else if filteredDishes.isEmpty {
                 VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(Color.white.opacity(0.3))
                    Text("No dishes in this category")
                        .foregroundColor(Color.white.opacity(0.6))
                }
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 16) {
                    ForEach(filteredDishes) { dish in
                        DishCard(
                            id: dish.id,
                            name: dish.name,
                            description: dish.description ?? "",
                            price: dish.price,
                            category: dish.category,
                            image: dish.thumbnail_url ?? "",
                            hasModel: (dish.model_url?.isEmpty == false),
                            onAddToCart: {
                                // Add to cart logic
                            },
                            onViewAR: {
                                // ✅ Trigger 3D Preview (inline pattern)
                                if let modelURL = dish.model_url,
                                   !modelURL.isEmpty,
                                   let url = URL(string: modelURL) {
                                    // Best Practice: Set URL and reset states BEFORE showing sheet
                                    selected3DModelURL = url
                                    local3DModelURL = nil
                                    download3DError = nil
                                    show3DPreview = true
                                    print("✅ 3D Preview triggered for dish: \(dish.name)")
                                } else {
                                    print("⚠️ No 3D model URL for dish: \(dish.name)")
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 140)
            }
        }
    }
    
    private var bottomActionButtons: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 12) {
                Button(action: onViewFullMenu) {
                    Text("View Full Menu")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(hex: "1e293b"))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                }
                
                Button(action: { showBookingSheet = true }) {
                    Text("Make a Reservation")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(hex: "3b82f6"))
                        .cornerRadius(16)
                        .shadow(color: Color.blue.opacity(0.4), radius: 12, x: 0, y: 4)
                }
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: [Theme.background.opacity(0), Theme.background.opacity(0.95), Theme.background],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .ignoresSafeArea(.keyboard)
    }
    
    private func loadData() async {
        print("🔄 loadData() called for restaurant: \(displayedProfile.restaurant_name ?? "unknown")")
        print("🔄 Owner ID: \(displayedProfile.id)")
        
        do {
            // Fetch dishes for this specific restaurant owner
            let allDishes = try await SupabaseManager.shared.fetchDishes(ownerId: displayedProfile.id)
            
            print("✅ Fetched \(allDishes.count) dishes successfully")
            
            // Fetch updated profile (for real-time bio/hours/address)
            let updatedProfile = try await SupabaseManager.shared.fetchProfile(userId: displayedProfile.id)
            
            await MainActor.run {
                self.dishes = allDishes
                self.liveProfile = updatedProfile
                print("✅ UI updated with \(allDishes.count) dishes")
            }
        } catch {
            print("❌ Error fetching real-time data: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            if let urlError = error as? URLError {
                print("❌ URLError code: \(urlError.code.rawValue)")
                print("❌ URLError description: \(urlError.errorUserInfo)")
            }
        }
    }
}

// Helper View for Info Rows
struct InfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "3b82f6")) // Blue-500
                .frame(width: 20)
            
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(Color.white.opacity(0.8))
        }
    }
}
