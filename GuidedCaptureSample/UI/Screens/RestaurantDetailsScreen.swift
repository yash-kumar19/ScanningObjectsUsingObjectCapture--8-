import SwiftUI

struct RestaurantDetailsScreenV2: View {
    // Callbacks
    var onBack: () -> Void
    var onDishClick: (String) -> Void
    
    // Data
    let restaurant: Restaurant
    @State private var liveRestaurant: Restaurant? // For real-time updates
    
    // Cart System
    @ObservedObject var cartManager = CartManager.shared
    @State private var showCartScreen = false
    @State private var showRestaurantConflictAlert = false
    @State private var pendingDish: Dish?
    
    // State
    @State private var selectedCategory: String = "Popular"
    @State private var activeImageIndex = 0
    private let galleryTimer = Timer.publish(every: 3.0, on: .main, in: .common).autoconnect()
    
    // Order checkout flow states
    @State private var showCustomerInfoSheet = false
    @State private var pendingConfirmState: OrderConfirmState? = nil
    @State private var pendingOrderId: String? = nil
    @State private var customerNamePrefill: String = ""
    @State private var showOrdersDetailsGlobal = false
    
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
    
    // Use live restaurant if available, otherwise fall back to initial
    var displayedRestaurant: Restaurant {
        liveRestaurant ?? restaurant
    }
    
    // Data accessors
    var restaurantName: String { displayedRestaurant.name }
    var location: String { displayedRestaurant.address ?? "Downtown" }
    var cuisine: String { displayedRestaurant.cuisine_type ?? "Fine Dining" }
    var phone: String { displayedRestaurant.phone ?? "+1 (555) 000-0000" }
    
    struct OpeningStatus {
        let isOpen: Bool
        let text: String
    }
    
    var openingStatus: OpeningStatus {
        guard let hoursDict = displayedRestaurant.opening_hours else {
            return OpeningStatus(isOpen: true, text: "Open Now")
        }
        
        let now = Date()
        let calendar = Calendar.current
        let weekdayIndex = calendar.component(.weekday, from: now) - 1
        let days = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
        let todayKey = days[weekdayIndex]
        
        guard let hours = hoursDict[todayKey] else {
            return OpeningStatus(isOpen: false, text: "Closed Today")
        }
        
        if hours.isClosed == true {
            return OpeningStatus(isOpen: false, text: "Closed Today")
        }
        
        guard let openStr = hours.open, let closeStr = hours.close else {
            return OpeningStatus(isOpen: true, text: "Open Now")
        }
        
        let openComponents = openStr.split(separator: ":").compactMap { Int($0) }
        let closeComponents = closeStr.split(separator: ":").compactMap { Int($0) }
        
        guard openComponents.count >= 2, closeComponents.count >= 2 else {
            return OpeningStatus(isOpen: true, text: "Open Now")
        }
        
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        
        let currentMinutesSinceMidnight = currentHour * 60 + currentMinute
        let openMinutesSinceMidnight = openComponents[0] * 60 + openComponents[1]
        let closeMinutesSinceMidnight = closeComponents[0] * 60 + closeComponents[1]
        
        if currentMinutesSinceMidnight >= openMinutesSinceMidnight && currentMinutesSinceMidnight <= closeMinutesSinceMidnight {
            return OpeningStatus(isOpen: true, text: "Open until \(closeStr)")
        } else {
            return OpeningStatus(isOpen: false, text: "Closed. Opens at \(openStr)")
        }
    }
    
    // Using formatted status
    var hours: String { openingStatus.text }
    var description: String { displayedRestaurant.description ?? "Experience culinary excellence in our establishment." }
    
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
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroHeader
                    infoCard
                    categoryFilter
                    dishList
                }
            }
            .ignoresSafeArea()
            .safeAreaInset(edge: .bottom) {
                // Floating Cart Bar (only shown when cart has items)
                if cartManager.itemCount > 0 {
                    FloatingCartBar(
                        cartManager: cartManager,
                        onTap: {
                            showCartScreen = true
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $showCartScreen) {
            CartScreen(
                onCheckout: {
                    showCartScreen = false
                    // Pre-fill name from logged-in profile's full_name
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
                    showCartScreen = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        showOrdersDetailsGlobal = true
                    }
                }
            )
        }
        .sheet(isPresented: $showCustomerInfoSheet) {
            CustomerInfoSheet(
                prefillName: customerNamePrefill,
                onConfirm: { name, e164Phone, notes in
                    pendingConfirmState = OrderConfirmState(
                        name: name, phone: e164Phone, notes: notes,
                        restaurantId: cartManager.restaurantId ?? displayedRestaurant.id
                    )
                    showCustomerInfoSheet = false
                }
            )
        }
        .fullScreenCover(item: $pendingConfirmState) { state in
            OrderConfirmationScreen(
                restaurantId: state.restaurantId,
                customerName: state.name,
                customerPhone: state.phone,
                specialNotes: state.notes,
                paymentMethod: .cash,
                onOrderPlaced: { orderId in
                    pendingOrderId = orderId
                    pendingConfirmState = nil
                    // Clear cart after checkout
                    cartManager.clear()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        showOrdersDetailsGlobal = true
                    }
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
        .alert("Replace cart items?", isPresented: $showRestaurantConflictAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear Cart", role: .destructive) {
                cartManager.clear()
                if let dish = pendingDish {
                    handleAddToCart(dish)
                }
            }
        } message: {
            Text("Your cart contains items from another restaurant. Clear it to add items from this restaurant?")
        }
        .fullScreenCover(isPresented: $show3DPreview) {
            // ✅ Inline 3D Preview (same pattern as OwnerMenuScreen)
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let localURL = local3DModelURL {
                    // Show the model using CustomModelViewer (which has its own close button)
                    ModelView(modelFile: localURL, endCaptureCallback: {
                        show3DPreview = false
                    })
                    .ignoresSafeArea()
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
            let urls = displayedRestaurant.gallery_urls ?? []
            
            if urls.count > 1 {
                TabView(selection: $activeImageIndex) {
                    ForEach(0..<urls.count, id: \.self) { index in
                        CachedAsyncImage(url: URL(string: urls[index])) { phase in
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
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 280)
                .onReceive(galleryTimer) { _ in
                    if urls.count > 1 {
                        withAnimation {
                            activeImageIndex = (activeImageIndex + 1) % urls.count
                        }
                    }
                }
            } else if urls.count == 1, let firstUrl = urls.first {
                CachedAsyncImage(url: URL(string: firstUrl)) { phase in
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
            } else {
                CachedAsyncImage(url: URL(string: displayedRestaurant.logo_url ?? "https://images.unsplash.com/photo-1559339352-11d035aa65de")) { phase in
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
            }
            
            // Subtle shadow gradient overlay to ensure page dots are visible
            LinearGradient(
                colors: [.clear, .black.opacity(0.4)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 280)
            .allowsHitTesting(false)
            
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
        .frame(height: 280)
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
                    LazyHStack(spacing: 12) {
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
                LazyVStack(spacing: 16) {
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
                                handleAddToCart(dish)
                            },
                            onViewAR: {
                                // ✅ Trigger 3D Preview (inline pattern)
                                print("🎯 [AR Button] Clicked for dish: \(dish.name)")
                                print("🎯 [AR Button] Dish ID: \(dish.id)")
                                print("🎯 [AR Button] Raw model_url from DB: \(dish.model_url ?? "nil")")
                                
                                if let modelURL = dish.model_url,
                                   !modelURL.isEmpty,
                                   let url = URL(string: modelURL) {
                                    // Best Practice: Set URL and reset states BEFORE showing sheet
                                    print("✅ [AR Button] Valid URL created: \(url.absoluteString)")
                                    print("✅ [AR Button] URL scheme: \(url.scheme ?? "nil")")
                                    print("✅ [AR Button] URL host: \(url.host ?? "nil")")
                                    
                                    selected3DModelURL = url
                                    local3DModelURL = nil
                                    download3DError = nil
                                    show3DPreview = true
                                    print("✅ 3D Preview triggered for dish: \(dish.name)")
                                } else {
                                    print("⚠️ No 3D model URL for dish: \(dish.name)")
                                    print("⚠️ model_url value: \(dish.model_url ?? "nil")")
                                    print("⚠️ isEmpty: \(dish.model_url?.isEmpty ?? true)")
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
    
    
    
    private func loadData() async {
        print("🔄 loadData() called for restaurant: \(displayedRestaurant.name)")
        print("🔄 Owner ID: \(displayedRestaurant.owner_id)")
        
        do {
            // Fetch dishes for this specific restaurant owner
            let allDishes = try await SupabaseManager.shared.fetchDishes(ownerId: displayedRestaurant.owner_id)
            
            print("✅ Fetched \(allDishes.count) dishes successfully")
            
            // Fetch updated restaurant profile
            let updatedRestaurant = try await SupabaseManager.shared.fetchPublicRestaurant(restaurantId: displayedRestaurant.id)
            
            await MainActor.run {
                self.dishes = allDishes
                self.liveRestaurant = updatedRestaurant
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
    
    // MARK: - Cart Helper Methods
    
    /// Handle adding dish to cart with restaurant conflict check
    private func handleAddToCart(_ dish: Dish) {
        // Check if trying to add from different restaurant
        if cartManager.isDifferentRestaurant(dish) {
            pendingDish = dish
            showRestaurantConflictAlert = true
            return
        }
        
        // Add to cart (CartManager handles conflict callback)
        cartManager.addItem(dish)
        
        // Store restaurant name if this is the first item
        if cartManager.itemCount == 1 {
            cartManager.restaurantName = restaurantName
        }
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Show global toast notification
        Task { @MainActor in
            ToastManager.shared.show("\(dish.name) added to cart")
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
