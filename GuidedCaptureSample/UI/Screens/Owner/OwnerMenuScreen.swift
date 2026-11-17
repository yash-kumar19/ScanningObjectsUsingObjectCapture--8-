import SwiftUI

// MARK: - Data Models
// Using Dish model from SupabaseManager


// MARK: - Helper Components
struct MenuDishCard: View {
    let dish: Dish
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onPreview: () -> Void
    let onRestore: (() -> Void)?
    
    @ObservedObject private var backgroundUploader = BackgroundUploader.shared
    
    private var uploadProgress: Double? {
        if let pendingList = UserDefaults.standard.array(forKey: "pending_dish_uploads") as? [[String: String]],
           let match = pendingList.first(where: { $0["dish_id"] == dish.id }),
           let sessionId = match["session_id"] {
            let state = match["upload_state"] ?? "uploading"
            if state == "failed" {
                return -1.0
            }
            if state == "failed_db" {
                return -2.0
            }
            if state == "processing" {
                return -3.0
            }
            // If state says "uploading" but no active upload exists,
            // the upload completed and UserDefaults hasn't been updated yet.
            // Treat as processing to avoid showing stale upload state.
            if let progress = backgroundUploader.activeUploads[sessionId] {
                return progress
            } else {
                return -3.0 // processing
            }
        }
        return nil
    }
    
    @ViewBuilder
    private func statusBadge() -> some View {
        if let progress = uploadProgress {
            if progress == -1.0 {
                badgeView(text: "Upload Failed", textColor: Color(hex: "ef4444"), bgColor: Color(hex: "ef4444").opacity(0.1), strokeColor: Color(hex: "ef4444").opacity(0.3))
            } else if progress == -2.0 {
                badgeView(text: "Database Sync Failed", textColor: Color(hex: "ef4444"), bgColor: Color(hex: "ef4444").opacity(0.1), strokeColor: Color(hex: "ef4444").opacity(0.3))
            } else if progress == -3.0 {
                badgeView(text: "3D Processing...", textColor: Color(hex: "f59e0b"), bgColor: Color(hex: "f59e0b").opacity(0.1), strokeColor: Color(hex: "f59e0b").opacity(0.3))
            } else {
                badgeView(text: "Uploading \(Int(progress * 100))%", textColor: Color(hex: "3b82f6"), bgColor: Color(hex: "3b82f6").opacity(0.1), strokeColor: Color(hex: "3b82f6").opacity(0.3))
            }
        } else if let effectiveStatus = dish.model_conversion_status ?? dish.generation_status,
                  effectiveStatus != "completed" && effectiveStatus != "ready" && dish.model_glb_url == nil {
            switch effectiveStatus {
            case "pending_upload":
                badgeView(text: "Pending Upload", textColor: Color(hex: "60a5fa"), bgColor: Color(hex: "60a5fa").opacity(0.1), strokeColor: Color(hex: "60a5fa").opacity(0.3))
            case "pending", "processing":
                badgeView(text: "3D Processing...", textColor: Color(hex: "f59e0b"), bgColor: Color(hex: "f59e0b").opacity(0.1), strokeColor: Color(hex: "f59e0b").opacity(0.3))
            case "failed":
                badgeView(text: "Failed", textColor: Color(hex: "ef4444"), bgColor: Color(hex: "ef4444").opacity(0.1), strokeColor: Color(hex: "ef4444").opacity(0.3))
            default:
                EmptyView()
            }
        } else if dish.is_active == false {
            badgeView(text: "Archived", textColor: Color(hex: "94a3b8"), bgColor: Color(hex: "475569").opacity(0.2), strokeColor: Color(hex: "94a3b8").opacity(0.2))
        } else if dish.status == "draft" {
            badgeView(text: "Draft", textColor: Color(hex: "94a3b8"), bgColor: Color(hex: "475569").opacity(0.2), strokeColor: Color(hex: "94a3b8").opacity(0.2))
        } else if dish.status == "published" {
            badgeView(text: "Published", textColor: Color(hex: "10b981"), bgColor: Color(hex: "10b981").opacity(0.1), strokeColor: Color(hex: "10b981").opacity(0.3))
        } else {
            EmptyView()
        }
    }
    
    private func badgeView(text: String, textColor: Color, bgColor: Color, strokeColor: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(textColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(bgColor)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(strokeColor, lineWidth: 1)
            )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Content
            HStack(alignment: .top, spacing: 16) {
                // Image
                CachedAsyncImage(url: URL(string: dish.thumbnail_url ?? "")) { phase in
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
                    
                    HStack(spacing: 8) {
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
                        
                        Spacer()
                        
                        statusBadge()
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
                
                if dish.is_active == false {
                    Button(action: {
                        if let onRestore = onRestore {
                            onRestore()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 14))
                            Text("Restore")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(Color(hex: "10b981"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(Color(hex: "10b981").opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "10b981").opacity(0.3), lineWidth: 1)
                        )
                    }
                } else {
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

struct MenuDishCardSkeleton: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .frame(width: 80, height: 80)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white)
                            .frame(width: 120, height: 20)
                        Spacer()
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white)
                            .frame(width: 32, height: 32)
                    }
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white)
                        .frame(width: 180, height: 16)
                    
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white)
                            .frame(width: 60, height: 22)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white)
                            .frame(width: 50, height: 16)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(16)
            
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, 16)
                
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .frame(maxWidth: .infinity, minHeight: 40, maxHeight: 40)
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .frame(maxWidth: .infinity, minHeight: 40, maxHeight: 40)
            }
            .padding(16)
            .padding(.top, -4)
        }
        .background(
            Color(hex: "1e293b"),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white, lineWidth: 1)
        )
        .skeleton(isLoading: true)
    }
}

// MARK: - Screen
@MainActor
struct OwnerMenuScreen: View {
    @Environment(AppDataModel.self) var appModel
    
    enum MenuTab: String, CaseIterable {
        case active = "Active"
        case drafts = "Drafts"
        case archive = "Archive"
    }
    
    @State private var selectedMenuTab: MenuTab = .active

    enum MenuSortOption {
        case nameAsc, nameDesc, priceAsc, priceDesc, dateNewest, dateOldest
    }
    
    @State private var selectedSort: MenuSortOption = .dateNewest
    @State private var selectedCategoryFilter: String? = nil

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
    
    var uniqueCategories: [String] {
        Set(dishes.map { $0.category }).sorted()
    }
    
    // Custom formatted dishes for view
    var filteredDishes: [Dish] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        var list: [Dish] = []
        
        switch selectedMenuTab {
        case .active:
            list = dishes.filter { $0.is_active != false && $0.status == "published" }
        case .drafts:
            list = dishes.filter { $0.is_active != false && $0.status == "draft" }
        case .archive:
            list = dishes.filter { $0.is_active == false }
        }
        
        if !query.isEmpty {
            list = list.filter { $0.name.localizedCaseInsensitiveContains(query) }
        }
        
        // Category Filter
        if let category = selectedCategoryFilter {
            list = list.filter { $0.category.localizedCaseInsensitiveCompare(category) == .orderedSame }
        }
        
        // Sorting
        switch selectedSort {
        case .nameAsc:
            list.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nameDesc:
            list.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        case .priceAsc:
            list.sort { $0.price < $1.price }
        case .priceDesc:
            list.sort { $0.price > $1.price }
        case .dateNewest:
            list.sort { ($0.created_at ?? "") > ($1.created_at ?? "") }
        case .dateOldest:
            list.sort { ($0.created_at ?? "") < ($1.created_at ?? "") }
        }
        
        // Optimistic UI: Hide the dish card immediately when deletion starts
        if isDeleting, let toDelete = dishToDelete {
            list = list.filter { $0.id != toDelete.id }
        }
        
        return list
    }
    
    private var hasPendingConversions: Bool {
        dishes.contains { dish in
            let status = dish.model_conversion_status ?? dish.generation_status ?? ""
            let isFinished = status == "ready" || status == "completed" || dish.model_glb_url != nil
            return (status == "pending" || status == "processing" || status == "pending_upload") && !isFinished
        }
    }
    
    private var headerView: some View {
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
    }

    private var tabSelectionView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MenuTab.allCases, id: \.self) { tab in
                    let count: Int = {
                        switch tab {
                        case .active:
                            return dishes.filter { $0.is_active != false && $0.status == "published" }.count
                        case .drafts:
                            return dishes.filter { $0.is_active != false && $0.status == "draft" }.count
                        case .archive:
                            return dishes.filter { $0.is_active == false }.count
                        }
                    }()
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            selectedMenuTab = tab
                        }
                    }) {
                        HStack(spacing: 6) {
                            Text(tab.rawValue)
                                .font(.system(size: 14, weight: .semibold))
                            Text("(\(count))")
                                .font(.system(size: 12, weight: .regular))
                                .opacity(0.7)
                        }
                        .foregroundColor(selectedMenuTab == tab ? .white : .white.opacity(0.6))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            selectedMenuTab == tab ?
                                AnyView(
                                    LinearGradient(
                                        colors: [Color(hex: "2b7fff"), Color(hex: "3b82f6")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                ) : AnyView(Color.white.opacity(0.05))
                        )
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(selectedMenuTab == tab ? Color(hex: "2b7fff").opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.top, -8)
    }

    private var searchAndFilterView: some View {
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
            
            // Filter Menu
            Menu {
                SwiftUI.Section("Sort") {
                    Button(action: { selectedSort = .dateNewest }) {
                        Label("Newest First", systemImage: selectedSort == .dateNewest ? "checkmark" : "")
                    }
                    Button(action: { selectedSort = .dateOldest }) {
                        Label("Oldest First", systemImage: selectedSort == .dateOldest ? "checkmark" : "")
                    }
                    Button(action: { selectedSort = .nameAsc }) {
                        Label("Name (A-Z)", systemImage: selectedSort == .nameAsc ? "checkmark" : "")
                    }
                    Button(action: { selectedSort = .nameDesc }) {
                        Label("Name (Z-A)", systemImage: selectedSort == .nameDesc ? "checkmark" : "")
                    }
                    Button(action: { selectedSort = .priceAsc }) {
                        Label("Price (Low to High)", systemImage: selectedSort == .priceAsc ? "checkmark" : "")
                    }
                    Button(action: { selectedSort = .priceDesc }) {
                        Label("Price (High to Low)", systemImage: selectedSort == .priceDesc ? "checkmark" : "")
                    }
                }
                
                SwiftUI.Section("Category") {
                    Button(action: { selectedCategoryFilter = nil }) {
                        Label("All Categories", systemImage: selectedCategoryFilter == nil ? "checkmark" : "")
                    }
                    
                    ForEach(uniqueCategories, id: \.self) { cat in
                        Button(action: { selectedCategoryFilter = cat }) {
                            Label(cat, systemImage: selectedCategoryFilter == cat ? "checkmark" : "")
                        }
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle") // Filter icon
                    .font(.system(size: 20))
                    .foregroundColor(selectedCategoryFilter != nil ? Color(hex: "2b7fff") : Color.white.opacity(0.6))
                    .frame(width: 56, height: 56) // Match search bar height roughly
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(selectedCategoryFilter != nil ? Color(hex: "2b7fff").opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
                    )
            }
        }
    }

    private var dishesListView: some View {
        Group {
            if isLoading && dishes.isEmpty {
                ForEach(0..<4, id: \.self) { _ in
                    MenuDishCardSkeleton()
                }
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
                                selectedModelURL = url
                                localModelURL = nil
                                downloadError = nil
                                showModelPreview = true
                                print("✅ Preview triggered with URL: \(url.absoluteString)")
                            } else {
                                print("⚠️ No model URL available for this dish")
                                showNoModelAlert = true
                            }
                        },
                        onRestore: {
                            Task {
                                await performRestore(dish)
                            }
                        }
                    )
                }
            }
        }
    }

    private var floatingActionButton: some View {
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

    var body: some View {
        ZStack {
            // 1. Unified Liquid Glass Background
            Theme.background.ignoresSafeArea()
            
            // 3. Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerView
                    tabSelectionView
                    searchAndFilterView
                    
                    if !isLoading {
                        UploadQueueView(dishes: dishes) { dish in
                            Task {
                                try? await SupabaseManager.shared.updateDishPartial(
                                    id: dish.id,
                                    generationStatus: "pending",
                                    modelConversionStatus: "pending"
                                )
                                await loadDishes()
                            }
                        }
                    }
                    
                    dishesListView
                }
                .padding(.bottom, 120) // Space for FAB and Tab Bar
                .padding(.horizontal, 24)
                .frame(maxWidth: 500)
            }
            
            // 4. Floating Action Button (FAB)
            floatingActionButton
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
            .environment(appModel)
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
            .environment(appModel)
        }
        .fullScreenCover(isPresented: $showModelPreview) {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let localURL = localModelURL {
                    ZStack(alignment: .topTrailing) {
                        ModelView(modelFile: localURL, endCaptureCallback: {
                            showModelPreview = false
                        })
                        .ignoresSafeArea()
                    }
                } else if downloader.isDownloading {
                    PremiumDownloadView(progress: downloader.downloadProgress, onCancel: {
                        showModelPreview = false
                    })
                } else if let error = downloadError {
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
                print("🔍 Preview sheet task started")
                print("🔍 selectedModelURL: \(selectedModelURL?.absoluteString ?? "nil")")
                
                guard let url = selectedModelURL else {
                    print("❌ No URL in selectedModelURL")
                    downloadError = "No model URL provided"
                    return
                }
                
                if url.isFileURL {
                    localModelURL = url
                    return
                }
                
                do {
                    let localURL = try await downloader.downloadModel(from: url)
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
            // Periodically poll database if there are active 3D model conversions
            while !Task.isCancelled {
                if hasPendingConversions {
                    await loadDishes()
                }
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
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
        .alert(selectedMenuTab == .archive ? "Permanently Delete" : "Delete Dish", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button(selectedMenuTab == .archive ? "Delete Permanently" : "Delete", role: .destructive) {
                Task {
                    if selectedMenuTab == .archive {
                        await performHardDelete()
                    } else {
                        await performDelete()
                    }
                }
            }
        } message: {
            if let dish = dishToDelete {
                if selectedMenuTab == .archive {
                    Text("Are you sure you want to PERMANENTLY delete '\(dish.name)'? This will remove all associated 3D models and images. This action cannot be undone.")
                } else {
                    Text("Delete '\(dish.name)'? This will hide it from customers, but data will be preserved.")
                }
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
        
        await MainActor.run {
            isDeleting = true
        }
        
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
        
        await MainActor.run {
            isDeleting = false
            dishToDelete = nil
        }
    }

    /// Perform resilient hard-delete on confirmed archived dish
    func performHardDelete() async {
        guard let dish = dishToDelete else { return }
        
        await MainActor.run {
            isDeleting = true
        }
        
        do {
            _ = try await SupabaseManager.shared.hardDeleteDish(dish: dish)
            await loadDishes() // Refresh list
            print("✅ Dish '\(dish.name)' database row hard-deleted.")
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
        
        await MainActor.run {
            isDeleting = false
            dishToDelete = nil
        }
    }

    /// Perform restore on dish
    func performRestore(_ dish: Dish) async {
        do {
            try await SupabaseManager.shared.restoreDish(id: dish.id)
            await loadDishes() // Refresh list
            print("✅ Dish '\(dish.name)' restored successfully")
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    func loadDishes() async {
        isLoading = true
        do {
            let fetchedDishes = try await SupabaseManager.shared.fetchOwnerDishes()
            
            // ─── Queue Cleanup (UserDefaults sync) ───────────────────────────────
            // IMPORTANT: Evaluate each signal independently — do NOT nest them inside
            // a single `if let` block. If both DB status fields are nil (e.g. during a
            // brief race condition after upload), the `if let status` guard fails and the
            // entire block is skipped — even if model_glb_url is already populated.
            // That's the root cause of the "stuck in queue forever" bug.
            var pendingList = UserDefaults.standard.array(forKey: "pending_dish_uploads") as? [[String: String]] ?? []
            var changed = false
            for dish in fetchedDishes {
                // Signal 1: model_glb_url is present → upload + processing are both done
                let hasModelURL = dish.model_glb_url != nil

                // Signal 2: DB status field explicitly marks the job as terminal
                let status = dish.model_conversion_status ?? dish.generation_status
                let isTerminalStatus = status == "ready" || status == "completed" || status == "failed"

                // Either signal alone is sufficient to clear the entry
                if hasModelURL || isTerminalStatus {
                    if let index = pendingList.firstIndex(where: { $0["dish_id"] == dish.id }) {
                        pendingList.remove(at: index)
                        changed = true
                        print("[Queue] Cleared dish \(dish.id) — hasModelURL=\(hasModelURL), status=\(status ?? "nil")")
                    }
                }
            }
            if changed {
                UserDefaults.standard.set(pendingList, forKey: "pending_dish_uploads")
            }
            
            await MainActor.run {
                self.dishes = fetchedDishes
            }
            
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


