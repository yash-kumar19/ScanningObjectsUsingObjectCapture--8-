import SwiftUI

// MARK: - Data Models
// Using Dish model from SupabaseManager


// MARK: - Helper Components
struct MenuDishCard: View {
    let dish: Dish
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onPreview: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Content
            HStack(alignment: .top, spacing: 16) {
                // Image
                AsyncImage(url: URL(string: dish.thumbnail_url ?? "")) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color.white.opacity(0.05))
                            .overlay(ProgressView())
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Rectangle()
                            .fill(Color.white.opacity(0.05))
                            .overlay(Image(systemName: "photo").foregroundColor(.white.opacity(0.3)))
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 16)) // Enforce clipping shape
                
                // Details
                VStack(alignment: .leading, spacing: 6) {
                    // Header Row: Title + Delete Button
                    HStack(alignment: .top, spacing: 8) {
                        Text(dish.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer()
                        
                        // Delete Button
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "f87171")) // red-400
                                .frame(width: 32, height: 32)
                                .background(Color(hex: "ef4444").opacity(0.1)) // red-500/10
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color(hex: "ef4444").opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                    
                    Text(dish.description ?? "")
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.6))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack(spacing: 10) {
                        Text(dish.category)
                            .font(.system(size: 12))
                            .foregroundColor(Color.white.opacity(0.7))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                        
                        Text(String(format: "$%.2f", dish.price))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "2b7fff"))
                    }
                    .padding(.top, 4)
                }
            }
            .padding(16)
            
            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, 16)
            
            // Action Buttons
            HStack(spacing: 8) {
                // Preview 3D Button - Always clickable, shows alert if no model
                Button(action: {
                    print("🔍 Preview button tapped for dish: \(dish.name)")
                    print("🔍 Model URL: \(dish.model_url ?? "nil")")
                    onPreview()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "eye")
                            .font(.system(size: 14))
                        Text("Preview 3D")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(dish.model_url != nil ? Color.white.opacity(0.7) : Color.white.opacity(0.3))
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
                
                Button(action: onEdit) {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil") // Edit2 -> pencil
                            .font(.system(size: 14))
                        Text("Edit")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(Color(hex: "2b7fff"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Color(hex: "2b7fff").opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "2b7fff").opacity(0.3), lineWidth: 1)
                    )
                }
            }
            .padding(16)
            .padding(.top, -4) // Adjust spacing to match React's pt-3 (12px) vs VStack spacing
        }
        .background(
            Color(hex: "1e293b"), // Dark non-glass background
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color(hex: "2b7fff").opacity(0.15), radius: 32, x: 0, y: 8)
    }
}

// MARK: - Screen
struct OwnerMenuScreen: View {
    @State private var searchQuery = ""
    @State private var dishes: [Dish] = []
    @State private var isLoading = false
    @State private var showAddDish = false
    
    // Preview State
    @State private var showModelPreview = false
    @State private var selectedModelURL: URL?
    @State private var showNoModelAlert = false
    
    // Download State (for inline preview)
    @StateObject private var downloader = ModelDownloader()
    @State private var localModelURL: URL?
    @State private var downloadError: String?
    
    // Edit & Delete State
    @State private var editingDish: Dish? = nil
    @State private var dishToDelete: Dish? = nil
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    // QR Menu State
    @State private var showQRMenu = false
    @State private var showQRTooltip = false
    @AppStorage("hasSeenQRTooltip") private var hasSeenQRTooltip = false
    @State private var restaurantName: String = "My Restaurant"
    
    // Custom formatted dishes for view
    var filteredDishes: [Dish] {
        let query = searchQuery
        let all = dishes
        if query.isEmpty {
            return all
        }
        let predicate: (Dish) -> Bool = { dish in
            dish.name.localizedCaseInsensitiveContains(query)
        }
        return all.filter(predicate)
    }
    
    var body: some View {
        ZStack {
            // 1. Unified Liquid Glass Background
            Theme.background.ignoresSafeArea()
            
            // 3. Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header with QR Icon
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("3D Menu")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundColor(.white)
                            Text("Manage your dishes and 3D models")
                                .font(.body)
                                .foregroundColor(Color.white.opacity(0.6))
                        }
                        
                        Spacer()
                        
                        // QR Icon Button
                        ZStack(alignment: .topTrailing) {
                            Button(action: { showQRMenu = true }) {
                                Image(systemName: "qrcode")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 48, height: 48)
                                    .background(Color(hex: "2b7fff").opacity(0.2))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(hex: "2b7fff").opacity(0.3), lineWidth: 1)
                                    )
                            }
                            
                            // One-time tooltip
                            if showQRTooltip {
                                VStack(spacing: 4) {
                                    Text("Share your menu with customers via QR")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color(hex: "2b7fff"))
                                        )
                                        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                                    
                                    // Arrow pointing down
                                    Image(systemName: "arrowtriangle.down.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(Color(hex: "2b7fff"))
                                        .offset(y: -8)
                                }
                                .offset(x: -80, y: -10)
                                .transition(.opacity)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 24)
                    
                    // Search and Filter
                    HStack(spacing: 12) {
                        // Search Bar
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 20))
                                .foregroundColor(Color.white.opacity(0.4))
                            
                            TextField("", text: $searchQuery)
                                .placeholder(when: searchQuery.isEmpty) {
                                    Text("Search dishes...").foregroundColor(Color.white.opacity(0.4))
                                }
                                .foregroundColor(.white)
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
                        
                        // Filter Button
                        Button(action: { /* Filter */ }) {
                            Image(systemName: "line.3.horizontal.decrease.circle") // Filter icon
                                .font(.system(size: 20))
                                .foregroundColor(Color.white.opacity(0.6))
                                .frame(width: 56, height: 56) // Match search bar height roughly
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        }
                    }
                    
                    // Dishes List
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .padding(.top, 40)
                    } else if filteredDishes.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "fork.knife.circle")
                                .font(.system(size: 48))
                                .foregroundColor(Color.white.opacity(0.3))
                            Text("No dishes found")
                                .foregroundColor(Color.white.opacity(0.6))
                        }
                        .padding(.top, 40)
                    } else {
                            ForEach(filteredDishes) { dish in
                                MenuDishCard(
                                    dish: dish,
                                    onEdit: { 
                                        editingDish = dish 
                                    },
                                    onDelete: { 
                                        requestDelete(dish) 
                                    },
                                    onPreview: {
                                        print("🔍 onPreview called for dish: \(dish.name)")
                                        print("🔍 Model URL value: \(dish.model_url ?? "nil")")
                                        if let modelURL = dish.model_url, !modelURL.isEmpty, let url = URL(string: modelURL) {
                                            // ✅ Best Practice: Set URL and reset states BEFORE showing sheet
                                            selectedModelURL = url
                                            localModelURL = nil
                                            downloadError = nil
                                            showModelPreview = true
                                            print("✅ Preview triggered with URL: \(url.absoluteString)")
                                        } else {
                                            print("⚠️ No model URL available for this dish")
                                            showNoModelAlert = true
                                        }
                                    }
                                )
                            }
                    }
                }
                .padding(.bottom, 120) // Space for FAB and Tab Bar
                .padding(.horizontal, 24)
                .frame(maxWidth: 500)
            }
            
            // 4. Floating Action Button (FAB)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { showAddDish = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "2b7fff"), Color(hex: "3b82f6")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Circle())
                            .shadow(color: Color(hex: "2b7fff").opacity(0.5), radius: 32, x: 0, y: 8)
                    }
                    .padding(.trailing, 24) // Increased padding to avoid cutoff
                    .padding(.bottom, 120) // Adjust based on tab bar height
                }
            }
        }
        .fullScreenCover(isPresented: $showAddDish) {
            AddEditDishScreen(
                onBack: { showAddDish = false },
                onSave: {
                    showAddDish = false
                    Task { await loadDishes() }
                },
                existingDish: nil
            )
        }
        .fullScreenCover(item: $editingDish) { dish in
            AddEditDishScreen(
                onBack: { editingDish = nil },
                onSave: {
                    editingDish = nil
                    Task { await loadDishes() }
                },
                existingDish: dish
            )
        }
        .fullScreenCover(isPresented: $showModelPreview) {
            // ✅ OPTION 1: Inline content - accesses selectedModelURL directly
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let localURL = localModelURL {
                    // Show the model using QuickLook
                    ZStack(alignment: .topTrailing) {
                        ModelView(modelFile: localURL, endCaptureCallback: {
                            showModelPreview = false
                        })
                        .ignoresSafeArea()
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
                        
                        Button(action: { showModelPreview = false }) {
                            Text("Cancel")
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color(hex: "1E293B"))
                                .cornerRadius(12)
                        }
                    }
                } else if let error = downloadError {
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
                        
                        Button(action: { showModelPreview = false }) {
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
                // ✅ Best Practice: Read selectedModelURL DIRECTLY from parent scope
                print("🔍 Preview sheet task started")
                print("🔍 selectedModelURL: \(selectedModelURL?.absoluteString ?? "nil")")
                
                guard let url = selectedModelURL else {
                    print("❌ No URL in selectedModelURL")
                    downloadError = "No model URL provided"
                    return
                }
                
                // If it's already a local file URL, use it directly
                if url.isFileURL {
                    localModelURL = url
                    return
                }
                
                // Otherwise, download from remote URL
                do {
                    let localURL = try await downloader.downloadModel(from: url)
                    
                    // 🔥 Give filesystem a moment to settle before Quick Look
                    try await Task.sleep(nanoseconds: 300_000_000) // 0.3s
                    
                    await MainActor.run {
                        localModelURL = localURL
                    }
                } catch {
                    await MainActor.run {
                        downloadError = error.localizedDescription
                    }
                }
            }
        }
        .task {
            await loadDishes()
            
            // Show QR tooltip on first visit
            if !hasSeenQRTooltip {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
                withAnimation {
                    showQRTooltip = true
                }
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3s duration
                withAnimation {
                    showQRTooltip = false
                }
                hasSeenQRTooltip = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .supabaseDataDidUpdate)) { _ in
            Task { await loadDishes() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .ownerShouldShowAddDishSheet)) { _ in
            showAddDish = true
        }
        .alert("No 3D Model", isPresented: $showNoModelAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This dish doesn't have a 3D model yet. Please create or upload one to preview.")
        }
        .alert("Delete Dish", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task { await performDelete() }
            }
        } message: {
            if let dish = dishToDelete {
                Text("Delete '\(dish.name)'? This will hide it from customers, but data will be preserved.")
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .sheet(isPresented: $showQRMenu) {
            if let userId = SupabaseManager.shared.currentUser?.id {
                QRMenuView(
                    restaurantId: userId,
                    restaurantName: restaurantName,
                    menuURL: AppConfig.menuURL(for: userId),
                    onDismiss: { showQRMenu = false }
                )
            } else {
                // Fallback if no user
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.yellow)
                    Text("Please log in to generate your QR code")
                        .multilineTextAlignment(.center)
                    Button("Close") { showQRMenu = false }
                        .padding()
                }
                .presentationDetents([.medium])
            }
        }
    }
    
    // MARK: - Helper Functions
    
    /// Centralized delete request - prevents double-trigger from swipe + button
    func requestDelete(_ dish: Dish) {
        // Prevent delete during upload
        guard dish.generation_status != "uploading" else {
            errorMessage = "Cannot delete while 3D model is uploading. Please wait for upload to complete."
            showError = true
            return
        }
        
        dishToDelete = dish
        showDeleteConfirmation = true
    }
    
    /// Perform soft-delete on confirmed dish
    func performDelete() async {
        guard let dish = dishToDelete else { return }
        
        isDeleting = true
        
        do {
            try await SupabaseManager.shared.softDeleteDish(id: dish.id)
            await loadDishes() // Refresh list
            print("✅ Dish '\(dish.name)' soft-deleted successfully")
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
        
        isDeleting = false
        dishToDelete = nil
    }
    
    func loadDishes() async {
        isLoading = true
        do {
            dishes = try await SupabaseManager.shared.fetchOwnerDishes()
            if let rest = try? await SupabaseManager.shared.fetchOwnerRestaurant() {
                await MainActor.run {
                    self.restaurantName = rest.name
                }
            }
        } catch {
            print("Error loading dishes: \(error)")
        }
        isLoading = false
    }
}

extension Notification.Name {
    static let ownerShouldShowAddDishSheet = Notification.Name("ownerShouldShowAddDishSheet")
}


