import SwiftUI
import PhotosUI

@MainActor
struct AddEditDishScreen: View {
    @Environment(AppDataModel.self) var appModel
    
    // Callbacks
    let onBack: () -> Void
    let onSave: () -> Void
    var existingDish: Dish? = nil  // Changed from dishId - determines edit vs add mode
    var prefilledModelURL: URL? = nil
    // Removed local upload tracking in favor of appModel.uploadState

    
    // UI State
    @State private var selectedTab: Int = 0 // 0: Details, 1: 3D Preview
    
    // Form State
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var price: String = ""
    @State private var category: String = ""
    @State private var status: String = "draft"
    @State private var modelURL: URL?
    
    // Field Change Tracking (for partial updates)
    @State private var userReplacedImage = false
    @State private var userCapturedNewModel = false
    @State private var initialModelURL: String?
    @State private var initialImageURL: String?
    
    // Image Upload State
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: Image?
    @State private var selectedImageData: Data?
    
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showModelPreview = false
    @State private var showCaptureSetup = false
    
    // Cellular warning
    @State private var showCellularWarning = false
    @State private var pendingSaveIgnoreCellular = false
    
    // Constants
    let categories = ["Starters", "Mains", "Desserts", "Beverages", "Sides"]
    
    var body: some View {
        ZStack {
            // Dark background
            Color(hex: "0F172A")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerTabsView
                
                // Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        if selectedTab == 0 {
                            detailsView
                        } else {
                            preview3DView
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 100) // Space for bottom buttons
                }
                
                bottomActionBar
            }
        }
        .onAppear {
            // Pre-populate if editing existing dish
            if let dish = existingDish {
                name = dish.name
                description = dish.description ?? ""
                price = String(format: "%.2f", dish.price)
                category = dish.category
                status = dish.status ?? "draft"
                initialModelURL = dish.model_url
                initialImageURL = dish.thumbnail_url
                
                // Load existing image asynchronously
                if let urlString = dish.thumbnail_url,
                   let url = URL(string: urlString) {
                    Task {
                        do {
                            let (data, _) = try await URLSession.shared.data(from: url)
                            if let uiImage = UIImage(data: data) {
                                await MainActor.run {
                                    selectedImage = Image(uiImage: uiImage)
                                    selectedImageData = data
                                }
                            }
                        } catch {
                            print("Failed to load existing image: \(error)")
                        }
                    }
                }
                
                // Set model URL if exists
                if let urlString = dish.model_url, let url = URL(string: urlString) {
                    modelURL = url
                }
            } else if let prefilled = prefilledModelURL {
                print("AddEditDishScreen appeared with prefilled URL: \(prefilled)")
                modelURL = prefilled
            } else {
                print("AddEditDishScreen appeared with NO prefilled URL")
            }
        }
        .onChange(of: prefilledModelURL) { oldUrl, newUrl in
            if let url = newUrl, existingDish == nil {
                print("prefilledModelURL changed to: \(url)")
                modelURL = url
                userCapturedNewModel = true
            }
        }
        // Image Selection Handler
        .onChange(of: selectedItem) { _, newItem in
            userReplacedImage = true  // Track explicit image change
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    if let uiImage = UIImage(data: data) {
                        await MainActor.run {
                            selectedImage = Image(uiImage: uiImage)
                            selectedImageData = data
                        }
                    }
                }
            }
        }
        .alert("Error", isPresented: $showError, actions: {
             Button("OK") { }
        }, message: {
            Text(errorMessage ?? "Unknown error")
        })
        .fullScreenCover(isPresented: $showModelPreview) {
             // Use ModelPreviewSheet that handles both local and remote URLs
             ModelPreviewSheet(
                 modelURL: appModel.localModelURL ?? modelURL ?? (existingDish?.model_url != nil ? URL(string: existingDish!.model_url!) : nil),
                 onDismiss: {
                     showModelPreview = false
                 }
             )
        }
        .sheet(isPresented: $showCaptureSetup) {
            CaptureSetupScreen(modelURL: $modelURL)
                .environment(appModel)
        }
        .onChange(of: modelURL) { _, newURL in
            if let newURL = newURL {
                userCapturedNewModel = true
                appModel.setLocalModelURL(newURL)
                withAnimation {
                    selectedTab = 1
                }
            }
        }
        .alert("Cellular Data Warning", isPresented: $showCellularWarning) {
            Button("Cancel", role: .cancel) { }
            Button("Continue") {
                pendingSaveIgnoreCellular = true
                saveDish()
            }
        } message: {
            Text("This upload is over 25MB. Continue using mobile data?")
        }
    }
    
    @Namespace private var namespace
    
    private var hasModelAvailable: Bool {
        existingDish?.model_url != nil || modelURL != nil || appModel.localModelURL != nil
    }
    
    // MARK: - Header Tabs
    private var headerTabsView: some View {
        VStack(spacing: 16) {
            Text(existingDish == nil ? "Add Dish" : "Edit Dish")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 16)
            
            // Custom Segmented Control (Always visible)
            HStack(spacing: 0) {
                // Details Tab
                Button(action: { withAnimation { selectedTab = 0 } }) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text")
                        Text("Details")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(selectedTab == 0 ? .white : .gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        ZStack {
                            if selectedTab == 0 {
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(Color(hex: "3B82F6"))
                                    .matchedGeometryEffect(id: "TAB", in: namespace)
                            }
                        }
                    )
                }
                
                // 3D Preview Tab
                Button(action: { withAnimation { selectedTab = 1 } }) {
                    HStack(spacing: 8) {
                        Image(systemName: "cube")
                        Text("3D Model")
                        if hasModelAvailable {
                            Circle()
                                .fill(Color(hex: "10B981"))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(selectedTab == 1 ? .white : .gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        ZStack {
                            if selectedTab == 1 {
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(Color(hex: "3B82F6"))
                                    .matchedGeometryEffect(id: "TAB", in: namespace)
                            }
                        }
                    )
                }
            }
            .padding(4)
            .background(Color(hex: "1E293B"))
            .clipShape(RoundedRectangle(cornerRadius: 30))
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Bottom Action Bar
    private var bottomActionBar: some View {
        HStack(spacing: 12) {
            // Cancel Button
            Button(action: onBack) {
                Text("Cancel")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(hex: "1E293B"))
                    .cornerRadius(12)
            }
            
            // Save Dish Button
            Button(action: saveDish) {
                if isSaving {
                    VStack(spacing: 4) {
                        ProgressView()
                            .tint(.white)
                        Text(existingDish == nil ? "Saving..." : "Updating...")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                } else {
                    Text(existingDish == nil ? "Add Dish" : "Save Changes")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(hex: "3B82F6"))
            .cornerRadius(12)
            .disabled(isSaving)
        }
        .padding(20)
        .background(Color(hex: "0F172A"))
    }
    
    // MARK: - Details View
    var detailsView: some View {
        VStack(spacing: 20) {
            
            // Image Upload Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Dish Image")
                    .font(.system(size: 14))
                    .foregroundColor(Color.white.opacity(0.7))
                
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                            .foregroundColor(Color(hex: "3B82F6").opacity(0.5))
                            .background(Color(hex: "1E293B").opacity(0.5))
                            .cornerRadius(16)
                            .frame(height: 200)
                        
                        if let img = selectedImage {
                            img
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        } else {
                            VStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: "3B82F6"))
                                        .frame(width: 60, height: 60)
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                }
                                
                                VStack(spacing: 4) {
                                    Text("Upload dish image")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                    Text("PNG, JPG up to 10MB")
                                        .font(.system(size: 13))
                                        .foregroundColor(Color.white.opacity(0.5))
                                }
                            }
                        }
                    }
                }
            }
            
            // 3D Model Attachment / Scan Section
            VStack(alignment: .leading, spacing: 8) {
                Text("3D Model")
                    .font(.system(size: 14))
                    .foregroundColor(Color.white.opacity(0.7))
                
                if hasModelAvailable {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(hex: "3B82F6").opacity(0.15))
                                .frame(width: 48, height: 48)
                            Image(systemName: "cube.fill")
                                .font(.system(size: 22))
                                .foregroundColor(Color(hex: "3B82F6"))
                        }
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text("3D Model Attached")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Ready for interactive AR menu")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "10B981"))
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Button(action: { showModelPreview = true }) {
                                Image(systemName: "eye.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(Color(hex: "3B82F6"))
                                    .clipShape(Circle())
                            }
                            
                            Button(action: { showCaptureSetup = true }) {
                                Image(systemName: "camera.viewfinder")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(Color(hex: "1E293B"))
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                            }
                        }
                    }
                    .padding(14)
                    .background(Color(hex: "1E293B"))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(hex: "3B82F6").opacity(0.3), lineWidth: 1)
                    )
                } else {
                    Button(action: { showCaptureSetup = true }) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(LinearGradient(colors: [Color(hex: "3B82F6").opacity(0.2), Color(hex: "8B5CF6").opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 48, height: 48)
                                Image(systemName: "camera.viewfinder")
                                    .font(.system(size: 22))
                                    .foregroundColor(Color(hex: "60A5FA"))
                            }
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Scan Dish in 3D")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("Use LiDAR & camera to create 3D model")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.white.opacity(0.6))
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.4))
                        }
                        .padding(14)
                        .background(Color(hex: "1E293B"))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color(hex: "3B82F6").opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // Dish Name
            VStack(alignment: .leading, spacing: 8) {
                Text("Dish Name")
                    .font(.system(size: 14))
                    .foregroundColor(Color.white.opacity(0.7))
                
                HStack(spacing: 12) {
                    Image(systemName: "tag")
                        .foregroundColor(Color(hex: "3B82F6"))
                    
                    TextField("e.g. Classic Burger", text: $name)
                        .foregroundColor(.white)
                        .accentColor(Color(hex: "3B82F6"))
                }
                .padding(16)
                .background(Color(hex: "1E293B"))
                .cornerRadius(12)
            }
            
            // Description
            VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                    .font(.system(size: 14))
                    .foregroundColor(Color.white.opacity(0.7))
                
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "text.alignleft")
                        .foregroundColor(Color(hex: "3B82F6"))
                        .padding(.top, 4)
                    
                    TextEditor(text: $description)
                        .foregroundColor(.white)
                        .scrollContentBackground(.hidden)
                        .frame(height: 80)
                        .accentColor(Color(hex: "3B82F6"))
                }
                .padding(16)
                .background(Color(hex: "1E293B"))
                .cornerRadius(12)
            }
            
            // Price
            VStack(alignment: .leading, spacing: 8) {
                Text("Price")
                    .font(.system(size: 14))
                    .foregroundColor(Color.white.opacity(0.7))
                
                HStack(spacing: 12) {
                    Image(systemName: "dollarsign.circle")
                        .foregroundColor(Color(hex: "3B82F6"))
                    
                    TextField("12.99", text: $price)
                        .foregroundColor(.white)
                        .keyboardType(.decimalPad)
                        .accentColor(Color(hex: "3B82F6"))
                }
                .padding(16)
                .background(Color(hex: "1E293B"))
                .cornerRadius(12)
            }
            
            // Category
            VStack(alignment: .leading, spacing: 8) {
                Text("Category")
                    .font(.system(size: 14))
                    .foregroundColor(Color.white.opacity(0.7))
                
                Menu {
                    ForEach(categories, id: \.self) { cat in
                        Button(cat) {
                            category = cat
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "tag")
                            .foregroundColor(Color(hex: "3B82F6"))
                        
                        Text(category.isEmpty ? "Select category" : category)
                            .foregroundColor(category.isEmpty ? Color.white.opacity(0.5) : .white)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .foregroundColor(Color.white.opacity(0.5))
                            .font(.system(size: 12))
                    }
                    .padding(16)
                    .background(Color(hex: "1E293B"))
                    .cornerRadius(12)
                }
            }
            
            // Status
            VStack(alignment: .leading, spacing: 8) {
                Text("Status")
                    .font(.system(size: 14))
                    .foregroundColor(Color.white.opacity(0.7))
                
                HStack(spacing: 12) {
                    // Draft Button
                    Button(action: { status = "draft" }) {
                        Text("Draft")
                            .font(.system(size: 15, weight: status == "draft" ? .semibold : .regular))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(status == "draft" ? Color(hex: "3B82F6") : Color(hex: "1E293B"))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(status == "draft" ? Color(hex: "3B82F6") : Color.white.opacity(0.1), lineWidth: 1)
                            )
                    }
                    
                    // Published Button
                    Button(action: { status = "published" }) {
                        Text("Published")
                            .font(.system(size: 15, weight: status == "published" ? .semibold : .regular))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(status == "published" ? Color(hex: "3B82F6") : Color(hex: "1E293B"))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(status == "published" ? Color(hex: "3B82F6") : Color.white.opacity(0.1), lineWidth: 1)
                            )
                    }
                }
            }
        }
    }
    
    // MARK: - 3D Preview View
    var preview3DView: some View {
        VStack(spacing: 20) {
            // 1. Static Preview / Status Card
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(hasModelAvailable ? Color(hex: "10B981").opacity(0.15) : Color(hex: "3B82F6").opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: hasModelAvailable ? "cube.fill" : "camera.viewfinder")
                        .font(.system(size: 38))
                        .foregroundColor(hasModelAvailable ? Color(hex: "10B981") : Color(hex: "3B82F6"))
                }
                
                VStack(spacing: 8) {
                    if hasModelAvailable {
                        Text("3D Model Ready")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(appModel.localModelURL != nil || modelURL != nil ? "Captured locally and ready to upload on save." : "Model is active on customer menu.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("No 3D Model Attached")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Capture your dish in 360° using Apple Object Capture photogrammetry.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(30)
            .frame(maxWidth: .infinity)
            .background(Color(hex: "1E293B"))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(hasModelAvailable ? Color(hex: "10B981").opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
            )
            
            // 2. Action Buttons
            if hasModelAvailable {
                Button(action: {
                    showModelPreview = true
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "arkit")
                            .font(.system(size: 18, weight: .semibold))
                        Text("View in 3D / AR")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(hex: "3B82F6"))
                    .cornerRadius(12)
                }
                
                Button(action: {
                    showCaptureSetup = true
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Retake 3D Scan")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(hex: "1E293B"))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
            } else {
                Button(action: {
                    showCaptureSetup = true
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text("Start 3D Capture")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(LinearGradient(colors: [Color(hex: "3B82F6"), Color(hex: "8B5CF6")], startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(12)
                    .shadow(color: Color(hex: "3B82F6").opacity(0.4), radius: 12, x: 0, y: 6)
                }
            }
        }
    }
    
    // MARK: - Save Logic
    private func saveDish() {
        // Validation
        guard !name.isEmpty else {
            errorMessage = "Please enter a dish name"
            showError = true
            return
        }
        
        guard !description.isEmpty else {
            errorMessage = "Please enter a description"
            showError = true
            return
        }
        
        guard !price.isEmpty, Double(price) != nil else {
            errorMessage = "Please enter a valid price"
            showError = true
            return
        }
        
        guard !category.isEmpty else {
            errorMessage = "Please select a category"
            showError = true
            return
        }
        
        // For edit mode, image is optional if already exists
        if existingDish == nil {
            guard selectedImageData != nil else {
                errorMessage = "Please upload an image"
                showError = true
                return
            }
        }
        
        if !pendingSaveIgnoreCellular, let url = appModel.localModelURL ?? modelURL, NetworkMonitor.shared.isCellular {
            if let attr = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attr[.size] as? Int64, size > 25 * 1024 * 1024 {
                showCellularWarning = true
                return
            }
        }
        
        isSaving = true
        
        Task {
            do {
                if let dish = existingDish {
                    // EDIT MODE - Partial update
                    try await performEdit(dish: dish)
                } else {
                    // CREATE MODE - Full dish creation
                    try await performCreate()
                }
                
                await MainActor.run {
                    isSaving = false
                    onSave() // Dismiss and refresh menu
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    // MARK: - Edit Existing Dish
    private func performEdit(dish: Dish) async throws {
        var finalImageURL: String? = nil
        if userReplacedImage, let imageData = selectedImageData {
            let imageName = UUID().uuidString
            finalImageURL = try await SupabaseManager.shared.uploadImage(data: imageData, name: imageName)
        }
        
        if userCapturedNewModel || appModel.localModelURL != nil {
            if let localURL = appModel.localModelURL ?? modelURL {
                let sessionId = appModel.captureSessionID.uuidString
                let token = try await SupabaseManager.shared.getValidAccessTokenOrRefresh()
                
                let pendingData: [String: String] = [
                    "dish_id": dish.id,
                    "local_path": localURL.path,
                    "session_id": sessionId,
                    "timestamp": String(Date().timeIntervalSince1970),
                    "upload_state": "uploading"
                ]
                
                var pendingList = UserDefaults.standard.array(forKey: "pending_dish_uploads") as? [[String:String]] ?? []
                pendingList.append(pendingData)
                UserDefaults.standard.set(pendingList, forKey: "pending_dish_uploads")
                
                try BackgroundUploader.shared.startUpload(
                    fileURL: localURL,
                    name: "\(sessionId).usdz",
                    dishId: dish.id,
                    intendedStatus: status,
                    sessionId: sessionId,
                    token: token
                )
            }
        }
        
        try await SupabaseManager.shared.updateDishPartial(
            id: dish.id,
            name: name,
            description: description.isEmpty ? nil : description,
            price: Double(price) ?? 0.0,
            category: category,
            imageURL: userReplacedImage ? finalImageURL : nil,
            modelURL: nil, // Let background handle it
            status: status
        )
    }
    
    // MARK: - Create New Dish
    private func performCreate() async throws {
        var uploadedImageURL: String? = nil
        if let imageData = selectedImageData {
            let imageName = UUID().uuidString
            uploadedImageURL = try await SupabaseManager.shared.uploadImage(data: imageData, name: imageName)
        }
        
        let intendedStatus = status
        let localURL = appModel.localModelURL ?? modelURL
        let isUploadingModel = localURL != nil
        
        let dish = try await SupabaseManager.shared.createDish(
            name: name,
            description: description,
            price: Double(price) ?? 0.0,
            category: category.isEmpty ? "Main Course" : category,
            modelURL: nil,
            thumbnailURL: uploadedImageURL,
            status: isUploadingModel ? "draft" : status,
            generationStatus: isUploadingModel ? "pending_upload" : "completed"
        )
        
        if let url = localURL {
             let sessionId = appModel.captureSessionID.uuidString
             let pendingData: [String: String] = [
                 "dish_id": dish.id,
                 "local_path": url.path,
                 "session_id": sessionId,
                 "timestamp": String(Date().timeIntervalSince1970),
                 "upload_state": "uploading"
             ]
             
             var pendingList = UserDefaults.standard.array(forKey: "pending_dish_uploads") as? [[String:String]] ?? []
             pendingList.append(pendingData)
             UserDefaults.standard.set(pendingList, forKey: "pending_dish_uploads")
             
             let token = try await SupabaseManager.shared.getValidAccessTokenOrRefresh()
             try BackgroundUploader.shared.startUpload(
                 fileURL: url,
                 name: "\(sessionId).usdz",
                 dishId: dish.id,
                 intendedStatus: intendedStatus,
                 sessionId: sessionId,
                 token: token
             )
        }
        
        print("✅ Dish '\(name)' created successfully")
    }
    

}

