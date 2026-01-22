import SwiftUI
import PhotosUI

struct AddEditDishScreen: View {
    @Environment(AppDataModel.self) var appModel
    
    // Callbacks
    let onBack: () -> Void
    let onSave: () -> Void
    var dishId: UUID? = nil
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
    
    // Image Upload State
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: Image?
    @State private var selectedImageData: Data?
    
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showModelPreview = false
    
    // Constants
    let categories = ["Starters", "Mains", "Desserts", "Beverages", "Sides"]
    
    var body: some View {
        ZStack {
            // Dark background
            Color(hex: "0F172A")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header / Tabs
                VStack(spacing: 20) {
                    // Custom Segmented Control
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
                                Text("3D Preview")
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
                    .padding(.top, 20)
                }
                
                // Content
                ScrollView {
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
                
                // Bottom Buttons
                HStack(spacing: 12) {
                    // Cancel Button
                    Button(action: {
                        onBack()
                    }) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(hex: "1E293B"))
                            .cornerRadius(12)
                    }
                    
                    // Add Dish Button
                    Button(action: saveDish) {
                        if isSaving {
                                VStack(spacing: 4) {
                                    ProgressView()
                                        .tint(.white)
                                    Text("Saving...")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                        } else {
                            Text("Add Dish")
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
        }
        .onChange(of: appModel.uploadState) { _, state in
            // React to upload state changes if needed (e.g. logging)
            print("AddEditDishScreen observed upload state change: \(state)")
        }
        .onAppear {
            if let prefilled = prefilledModelURL {
                print("AddEditDishScreen appeared with prefilled URL: \(prefilled)")
                modelURL = prefilled
            } else {
                print("AddEditDishScreen appeared with NO prefilled URL")
            }
        }
        .onChange(of: prefilledModelURL) { oldUrl, newUrl in
            if let url = newUrl {
                print("prefilledModelURL changed to: \(url)")
                modelURL = url
            }
        }
        // Image Selection Handler
        .onChange(of: selectedItem) { _, newItem in
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
                 modelURL: appModel.localModelURL ?? modelURL,
                 onDismiss: {
                     showModelPreview = false
                 }
             )
        }
    }
    
    @Namespace private var namespace
    
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
                        
                        if let selectedImage {
                            selectedImage
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
    // MARK: - 3D Preview View
    var preview3DView: some View {
        VStack(spacing: 20) {
             // 1. Static Preview / Status Card
             VStack(spacing: 16) {
                 ZStack {
                     Circle()
                         .fill(Color(hex: "3B82F6").opacity(0.1))
                         .frame(width: 80, height: 80)
                     
                     Image(systemName: "cube.fill")
                         .font(.system(size: 40))
                         .foregroundColor(Color(hex: "3B82F6"))
                 }
                 
                 VStack(spacing: 8) {
                     if case .completed = appModel.uploadState {
                         Text("Model Ready")
                             .font(.headline)
                             .foregroundColor(.white)
                         Text("Your 3D model has been processed and is ready to view.")
                             .font(.caption)
                             .foregroundColor(.gray)
                             .multilineTextAlignment(.center)
                     } else if case .uploading = appModel.uploadState {
                         Text("Processing...")
                             .font(.headline)
                             .foregroundColor(.white)
                         ProgressView()
                             .tint(.white)
                     } else if appModel.localModelURL != nil || modelURL != nil {
                          Text("Capture Complete")
                             .font(.headline)
                             .foregroundColor(.white)
                          Text("Model is saved locally and ready to upload.")
                             .font(.caption)
                             .foregroundColor(.gray)
                             .multilineTextAlignment(.center)
                     } else {
                         Text("No Model")
                             .font(.headline)
                             .foregroundColor(.white)
                         Text("Capture a 3D model to see it here.")
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
                     .stroke(Color.white.opacity(0.1), lineWidth: 1)
             )
             
             // 2. Action Button (View 3D Model) - Works with both local and remote URLs
             Button(action: {
                 showModelPreview = true
             }) {
                 HStack {
                     Image(systemName: "arkit")
                     Text("View 3D Model")
                 }
                 .font(.headline)
                 .foregroundColor(.white)
                 .frame(maxWidth: .infinity)
                 .padding()
                 .background(Color(hex: "3B82F6"))
                 .cornerRadius(12)
             }
             .disabled(appModel.localModelURL == nil && modelURL == nil)
             .opacity((appModel.localModelURL == nil && modelURL == nil) ? 0.5 : 1.0)
        }
    }
    
    // MARK: - Save Logic
    private func saveDish() {
        // Validation
        guard selectedImageData != nil else {
            errorMessage = "Please upload an image"
            showError = true
            return
        }
        
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
        
        isSaving = true
        
        Task {
            do {
                // 1. Upload Image (Mandatory)
                var uploadedImageURL: String? = nil
                if let imageData = selectedImageData {
                    let imageName = UUID().uuidString
                    uploadedImageURL = try await SupabaseManager.shared.uploadImage(data: imageData, name: imageName)
                }
                
                // 2. Handle 3D Model with Timeout Logic
                var finalModelURL: String? = nil
                
                // ✅ DATA-DRIVEN: Upload already started in setLocalModelURL()
                // Just check current state and wait if needed
                if case .completed(let url) = appModel.uploadState {
                    finalModelURL = url.absoluteString
                }
                // No need to trigger upload - it's already running from setLocalModelURL()
                
                
                // If not yet available, wait with timeout
                if finalModelURL == nil {
                    // Wait up to 60 seconds for upload to complete
                    let timeoutNanoseconds: UInt64 = 60 * 1_000_000_000
                    let startTime = DispatchTime.now()
                    
                    while finalModelURL == nil {
                        // Check if time exceeded
                        let currentTime = DispatchTime.now()
                        if currentTime.uptimeNanoseconds - startTime.uptimeNanoseconds > timeoutNanoseconds {
                            print("Save timeout reached waiting for upload. Proceeding with pending status.")
                            break 
                        }
                        
                        // Check state again
                        if case .completed(let url) = appModel.uploadState {
                            finalModelURL = url.absoluteString
                            break
                        }
                        if case .failed = appModel.uploadState {
                            // If failed during wait, proceed as pending (so retry can happen later)
                            break
                        }
                        
                        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s poll
                    }
                }
                
                // 3. Create Dish
                let priceValue = Double(price) ?? 0.0
                let generationStatus = finalModelURL == nil ? "pending_upload" : "completed"
                
                let dish = try await SupabaseManager.shared.createDish(
                    name: name,
                    description: description,
                    price: priceValue,
                    category: category.isEmpty ? "Main Course" : category,
                    modelURL: finalModelURL, // Pass nil if pending
                    thumbnailURL: uploadedImageURL,
                    status: status,
                    generationStatus: generationStatus
                )
                
                // 4. Robust Persistence for Pending Uploads
                if finalModelURL == nil, let local = appModel.localModelURL {
                     let pendingData: [String: String] = [
                         "dish_id": dish.id,
                         "local_path": local.path,
                         "session_id": appModel.captureSessionID.uuidString,
                         "timestamp": String(Date().timeIntervalSince1970)
                     ]
                     
                     // Append to UserDefaults list
                     var pendingList = UserDefaults.standard.array(forKey: "pending_dish_uploads") as? [[String:String]] ?? []
                     pendingList.append(pendingData)
                     UserDefaults.standard.set(pendingList, forKey: "pending_dish_uploads")
                     
                     print("Saved pending upload details for dish \(dish.id) locally.")
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
}

