import SwiftUI

struct AddEditDishScreen: View {
    // Callbacks
    var onBack: () -> Void
    var onSave: () -> Void
    var dishId: String?
    
    // State
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var price: String = ""
    @State private var category: String = ""
    @State private var status: String = "draft"
    @State private var modelURL: URL?
    @State private var showPreview = false
    
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    init(onBack: @escaping () -> Void, onSave: @escaping () -> Void, dishId: String? = nil, initialModelURL: URL? = nil) {
        self.onBack = onBack
        self.onSave = onSave
        self.dishId = dishId
        _modelURL = State(initialValue: initialModelURL)
    }
    
    // Data
    let categories = ["Appetizer", "Main Course", "Dessert", "Beverage", "Side Dish"]
    let statuses = [
        (value: "draft", label: "Draft"),
        (value: "published", label: "Published")
    ]
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            GlowBackground()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: onBack) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.left")
                            Text("Back")
                        }
                        .foregroundColor(Theme.textSecondary)
                    }
                    
                    Spacer()
                    
                    Text(dishId != nil ? "Edit Dish" : "Add New Dish")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Spacer for balance
                    Color.clear.frame(width: 60, height: 44)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 24)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Image Uploader
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Dish Image")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                            
                            GlassCard {
                                VStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(LinearGradient(colors: [Theme.primaryBlue, Theme.primaryBlue.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                            .frame(width: 64, height: 64)
                                            .shadow(color: Theme.primaryBlue.opacity(0.3), radius: 24, x: 0, y: 8)
                                        
                                        Image(systemName: "photo")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                    }
                                    
                                    Text("Upload dish image")
                                        .font(.body)
                                        .foregroundColor(.white)
                                    
                                    Text("PNG, JPG up to 10MB")
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                                    .foregroundColor(Theme.primaryBlue.opacity(0.3))
                            )
                        }
                        
                        // 3D Model Uploader
                        VStack(alignment: .leading, spacing: 8) {
                            Text("3D Model (Optional)")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                            
                            GlassCard {
                                VStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(LinearGradient(colors: [Theme.primaryPurple, Theme.primaryPurple.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                            .frame(width: 64, height: 64)
                                            .shadow(color: Theme.primaryPurple.opacity(0.3), radius: 24, x: 0, y: 8)
                                        
                                        Image(systemName: modelURL != nil ? "checkmark.circle.fill" : "cube")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                    }
                                    
                                    Text(modelURL != nil ? "Model Attached" : "Upload 3D model")
                                        .font(.body)
                                        .foregroundColor(.white)
                                    
                                    if let url = modelURL {
                                        Text(url.lastPathComponent)
                                            .font(.caption)
                                            .foregroundColor(Theme.textSecondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        
                                        Button(action: { showPreview = true }) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "eye.fill")
                                                Text("Preview 3D")
                                            }
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Theme.primaryPurple.opacity(0.3))
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Theme.primaryPurple.opacity(0.5), lineWidth: 1)
                                            )
                                        }
                                        .padding(.top, 4)
                                    } else {
                                        Text("GLB, GLTF, USDZ up to 50MB")
                                            .font(.caption)
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                                    .foregroundColor(Theme.primaryPurple.opacity(0.3))
                            )
                        }
                        
                        // Form Fields
                        GlassInput(label: "Dish Name", text: $name, icon: "tag", placeholder: "e.g. Classic Burger")
                        
                        GlassInput(label: "Description", text: $description, icon: "text.alignleft", placeholder: "Describe your dish...", isMultiline: true)
                        
                        GlassInput(label: "Price", text: $price, icon: "dollarsign.circle", placeholder: "12.99", keyboardType: .decimalPad)
                        
                        // Category Picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Category")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                            
                            GlassCard(padding: 0) {
                                HStack {
                                    Image(systemName: "tag")
                                        .foregroundColor(Theme.primaryBlue)
                                    
                                    Menu {
                                        ForEach(categories, id: \.self) { cat in
                                            Button(cat) {
                                                category = cat
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Text(category.isEmpty ? "Select category" : category)
                                                .foregroundColor(category.isEmpty ? Theme.textSecondary : .white)
                                            Spacer()
                                            Image(systemName: "chevron.down")
                                                .font(.caption)
                                                .foregroundColor(Theme.textSecondary)
                                        }
                                    }
                                }
                                .padding(16)
                            }
                        }
                        
                        // Status
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Status")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                            
                            HStack(spacing: 12) {
                                ForEach(statuses, id: \.value) { stat in
                                    Button(action: { status = stat.value }) {
                                        Text(stat.label)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(status == stat.value ? Theme.primaryBlue.opacity(0.2) : Color.white.opacity(0.05))
                                            .foregroundColor(status == stat.value ? .white : Theme.textSecondary)
                                            .cornerRadius(16)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(status == stat.value ? Theme.primaryBlue : Color.white.opacity(0.08), lineWidth: 1)
                                            )
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 120) // Space for bottom bar
                }
                
                // Bottom Bar
                VStack {
                    Divider().background(Color.white.opacity(0.08))
                    HStack(spacing: 12) {
                        Button(action: onBack) {
                            Text("Cancel")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        }
                        .disabled(isSaving)
                        
                        Button(action: saveDish) {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Theme.gradientBlue)
                                    .cornerRadius(20)
                            } else {
                                Text(dishId != nil ? "Save Changes" : "Add Dish")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Theme.gradientBlue)
                                    .cornerRadius(20)
                                    .shadow(color: Theme.primaryBlue.opacity(0.4), radius: 16, x: 0, y: 8)
                            }
                        }
                        .disabled(isSaving)
                    }
                    .padding(24)
                    .background(Theme.background.opacity(0.9))
                }
            }
        }
        .sheet(isPresented: $showPreview) {
            if let url = modelURL {
                Preview3DView(url: url)
            }
        }
        .alert("Error", isPresented: $showError, actions: {
            Button("OK") { }
        }, message: {
            Text(errorMessage ?? "Unknown error")
        })
    }
    
    private func saveDish() {
        guard !name.isEmpty else {
            errorMessage = "Please enter a dish name"
            showError = true
            return
        }
        
        isSaving = true
        
        Task {
            do {
                var uploadedModelURL = ""
                
                // Upload Model if exists
                if let modelURL = modelURL {
                    // Generate unique name
                    let filename = "\(UUID().uuidString).usdz"
                    uploadedModelURL = try await SupabaseManager.shared.uploadModel(fileURL: modelURL, name: filename)
                }
                
                // Upload Image (Placeholder for now as UI doesn't have image picker yet)
                // In a real app, we would have picked an image data here
                
                let priceValue = Double(price) ?? 0.0
                
                _ = try await SupabaseManager.shared.createDish(
                    name: name,
                    description: description,
                    price: priceValue,
                    category: category.isEmpty ? "Main Course" : category,
                    modelURL: uploadedModelURL,
                    thumbnailURL: nil // Placeholder
                )
                
                await MainActor.run {
                    isSaving = false
                    onSave() // Dismiss
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
