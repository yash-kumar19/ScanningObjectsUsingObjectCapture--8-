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
            ZStack(alignment: .topTrailing) {
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
                    .cornerRadius(16)
                    .clipped()
                    
                    // Details
                    VStack(alignment: .leading, spacing: 6) {
                        Text(dish.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.trailing, 60) // Increased space for delete button
                        
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
                .padding(.top, 6) // Moved up more
                .padding(.trailing, 16)
            }
            
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
    
    // Custom formatted dishes for view
    var filteredDishes: [Dish] {
        if searchQuery.isEmpty {
            return dishes
        } else {
            return dishes.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
        }
    }
    
    var body: some View {
        ZStack {
            // 1. Unified Liquid Glass Background
            Theme.background.ignoresSafeArea()
            
            // 3. Content
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("3D Menu")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.white)
                        Text("Manage your dishes and 3D models")
                            .font(.body)
                            .foregroundColor(Color.white.opacity(0.6))
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
                                    onEdit: { /* Edit dish */ },
                                    onDelete: { /* Delete dish */ },
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
                dishId: nil
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
                        
                        // Close Button
                        Button(action: { showModelPreview = false }) {
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
        }
        .onReceive(NotificationCenter.default.publisher(for: .supabaseDataDidUpdate)) { _ in
            Task { await loadDishes() }
        }
        .alert("No 3D Model", isPresented: $showNoModelAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This dish doesn't have a 3D model yet. Please create or upload one to preview.")
        }
    }
    
    func loadDishes() async {
        isLoading = true
        do {
            dishes = try await SupabaseManager.shared.fetchOwnerDishes()
        } catch {
            print("Error loading dishes: \(error)")
        }
        isLoading = false
    }
}

