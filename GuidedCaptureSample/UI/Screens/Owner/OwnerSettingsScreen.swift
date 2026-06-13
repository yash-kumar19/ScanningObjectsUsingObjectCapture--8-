import SwiftUI
import PhotosUI

enum EditField: String, Identifiable {
    case restaurantName
    case cuisineType
    case phone
    case address
    case description
    case ownerName
    
    var id: String { rawValue }
}

struct OwnerSettingsScreen: View {
    var onLogout: () -> Void
    @Binding var hasUnsavedChangesBinding: Bool
    var actionHandler: SettingsActionHandler
    
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String? = nil
    
    // Original states for change detection
    @State private var originalRestaurantName = ""
    @State private var originalRestaurantDescription = ""
    @State private var originalRestaurantCuisine = ""
    @State private var originalRestaurantPhone = ""
    @State private var originalRestaurantAddress = ""
    @State private var originalRestaurantCity = ""
    @State private var originalRestaurantPincode = ""
    @State private var originalLogoUrl = ""
    @State private var originalGalleryUrls: [String] = []
    @State private var originalOpeningHours: [String: OpeningHourDay] = [:]
    @State private var originalOwnerName = ""
    @State private var originalOwnerPhone = ""
    
    // Restaurant State
    @State private var restaurantName = ""
    @State private var restaurantDescription = ""
    @State private var restaurantCuisine = ""
    @State private var restaurantPhone = ""
    @State private var restaurantAddress = ""
    @State private var restaurantCity = ""
    @State private var restaurantPincode = ""
    @State private var logoUrl = ""
    @State private var galleryUrls: [String] = []
    @State private var openingHours: [String: OpeningHourDay] = [:]
    
    // Owner Account State
    @State private var ownerName = ""
    @State private var accountEmail = ""
    @State private var ownerPhone = ""
    
    // Local App Settings (toggles)
    @State private var notificationsNewReservations = true
    @State private var notificationsOrderUpdates = true
    @State private var notificationsMarketing = false
    @State private var twoFactorEnabled = false
    
    // Image Pickers
    @State private var selectedLogoItem: PhotosPickerItem?
    @State private var selectedGalleryItem: PhotosPickerItem?
    @State private var isUploadingLogo = false
    @State private var isUploadingGallery = false
    
    // Sheets presentation
    @State private var activeEditField: EditField? = nil
    @State private var showHoursEditor = false
    @State private var showDeleteConfirmation = false
    
    // Days array for sorting opening hours
    let daysOfWeek = [
        (id: "mon", label: "Monday"),
        (id: "tue", label: "Tuesday"),
        (id: "wed", label: "Wednesday"),
        (id: "thu", label: "Thursday"),
        (id: "fri", label: "Friday"),
        (id: "sat", label: "Saturday"),
        (id: "sun", label: "Sunday")
    ]
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            if isLoading {
                ProgressView("Loading settings...")
                    .tint(.white)
                    .foregroundColor(.white)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        // Header
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Settings")
                                    .font(.system(size: 34, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Manage your restaurant and account")
                                    .font(.body)
                                    .foregroundColor(Color.white.opacity(0.6))
                            }
                            Spacer()
                            
                            if isSaving {
                                ProgressView().tint(.white).padding(.bottom, 8)
                            } else {
                                Button(action: saveAllSettings) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("Save")
                                    }
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Theme.gradientBlue)
                                    .cornerRadius(12)
                                }
                                .padding(.bottom, 8)
                            }
                        }
                        .padding(.top, 24)
                        
                        if let error = errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        // Restaurant Information
                        SettingsSection(title: "Restaurant Information", icon: "storefront.fill") {
                            VStack(spacing: 0) {
                                Button(action: { activeEditField = .restaurantName }) {
                                    SettingsRow(icon: "storefront.fill", label: "Restaurant Name", value: restaurantName.isEmpty ? "Not set" : restaurantName)
                                }
                                Divider().background(Color.white.opacity(0.05)).padding(.leading, 48)
                                
                                Button(action: { activeEditField = .cuisineType }) {
                                    SettingsRow(icon: "sparkles", label: "Cuisine Type", value: restaurantCuisine.isEmpty ? "Not set" : restaurantCuisine)
                                }
                                Divider().background(Color.white.opacity(0.05)).padding(.leading, 48)
                                
                                Button(action: { activeEditField = .phone }) {
                                    SettingsRow(icon: "phone.fill", label: "Phone", value: restaurantPhone.isEmpty ? "Not set" : restaurantPhone)
                                }
                                Divider().background(Color.white.opacity(0.05)).padding(.leading, 48)
                                
                                Button(action: { activeEditField = .address }) {
                                    let fullAddr = [restaurantAddress, restaurantCity, restaurantPincode].filter { !$0.isEmpty }.joined(separator: ", ")
                                    SettingsRow(icon: "map.fill", label: "Address", value: fullAddr.isEmpty ? "Not set" : fullAddr)
                                }
                                Divider().background(Color.white.opacity(0.05)).padding(.leading, 48)
                                
                                Button(action: { activeEditField = .description }) {
                                    SettingsRow(icon: "doc.text.fill", label: "Description / Bio", value: restaurantDescription.isEmpty ? "Not set" : restaurantDescription)
                                }
                                Divider().background(Color.white.opacity(0.05)).padding(.leading, 48)
                                
                                // Logo Row
                                HStack {
                                    Image(systemName: "photo.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(Color(hex: "2b7fff"))
                                        .frame(width: 20)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Logo Image")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color.white.opacity(0.6))
                                        if isUploadingLogo {
                                            ProgressView().tint(.white).scaleEffect(0.8)
                                        } else {
                                            Text(logoUrl.isEmpty ? "Not set" : "Custom Logo Uploaded")
                                                .font(.system(size: 14))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    Spacer()
                                    
                                    if !logoUrl.isEmpty {
                                        AsyncImage(url: URL(string: logoUrl)) { image in
                                            image.resizable().aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            ProgressView().tint(.white)
                                        }
                                        .frame(width: 40, height: 40)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .padding(.trailing, 8)
                                    }
                                    
                                    PhotosPicker(selection: $selectedLogoItem, matching: .images) {
                                        Image(systemName: "square.and.arrow.up")
                                            .foregroundColor(Color(hex: "2b7fff"))
                                    }
                                }
                                .padding(12)
                                
                                Divider().background(Color.white.opacity(0.05)).padding(.leading, 48)
                                
                                Button(action: { showHoursEditor = true }) {
                                    SettingsRow(icon: "clock.fill", label: "Hours", value: "Configure Weekly Hours")
                                }
                            }
                        }
                        
                        // Photo Gallery Section
                        SettingsSection(title: "Photo Gallery (\(galleryUrls.count)/5)", icon: "photo.on.rectangle.angled") {
                            VStack(spacing: 12) {
                                if galleryUrls.isEmpty {
                                    Text("No gallery images uploaded yet.")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color.white.opacity(0.4))
                                        .padding(.vertical, 16)
                                } else {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            ForEach(Array(galleryUrls.enumerated()), id: \.offset) { idx, url in
                                                ZStack(alignment: .topTrailing) {
                                                    AsyncImage(url: URL(string: url)) { image in
                                                        image.resizable().aspectRatio(contentMode: .fill)
                                                    } placeholder: {
                                                        ProgressView().tint(.white)
                                                    }
                                                    .frame(width: 80, height: 80)
                                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                                    
                                                    Button(action: {
                                                        galleryUrls.remove(at: idx)
                                                    }) {
                                                        Image(systemName: "xmark.circle.fill")
                                                            .foregroundColor(.red)
                                                            .background(Circle().fill(Color.black))
                                                    }
                                                    .offset(x: 6, y: -6)
                                                }
                                            }
                                        }
                                        .padding(.vertical, 8)
                                    }
                                }
                                
                                if isUploadingGallery {
                                    ProgressView().tint(.white).padding(.vertical, 4)
                                } else if galleryUrls.count < 5 {
                                    PhotosPicker(selection: $selectedGalleryItem, matching: .images) {
                                        HStack {
                                            Image(systemName: "plus")
                                            Text("Add Photo to Gallery")
                                        }
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Color(hex: "2b7fff"))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Color.white.opacity(0.05))
                                        .cornerRadius(10)
                                    }
                                }
                            }
                            .padding(16)
                        }
                        
                        // Owner Account
                        SettingsSection(title: "Owner Account", icon: "person.fill") {
                            VStack(spacing: 0) {
                                Button(action: { activeEditField = .ownerName }) {
                                    SettingsRow(icon: "person.fill", label: "Owner Name", value: ownerName.isEmpty ? "Not set" : ownerName)
                                }
                                Divider().background(Color.white.opacity(0.05)).padding(.leading, 48)
                                
                                SettingsRow(icon: "envelope.fill", label: "Account Email", value: accountEmail, showChevron: false)
                                
                                if !ownerPhone.isEmpty {
                                    Divider().background(Color.white.opacity(0.05)).padding(.leading, 48)
                                    SettingsRow(icon: "phone.fill", label: "Phone Number", value: ownerPhone, showChevron: false)
                                }
                            }
                        }
                        
                        // Two-Step Authentication
                        SettingsSection(title: "Two-Step Authentication", icon: "shield.fill") {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Enable 2FA")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                    Text("Add an extra layer of security to your account")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color.white.opacity(0.6))
                                }
                                Spacer()
                                CustomToggle(isOn: $twoFactorEnabled)
                            }
                            .padding(16)
                        }
                        
                        // Notification Settings
                        SettingsSection(title: "Notification Settings", icon: "bell.fill") {
                            VStack(spacing: 16) {
                                NotificationToggleRow(title: "New Reservations", isOn: $notificationsNewReservations)
                                NotificationToggleRow(title: "Order Updates", isOn: $notificationsOrderUpdates)
                                NotificationToggleRow(title: "Marketing", isOn: $notificationsMarketing)
                            }
                            .padding(16)
                        }
                        
                        // Delete Restaurant card (Danger Zone matching website)
                        SettingsSection(title: "Danger Zone", icon: "exclamationmark.triangle.fill") {
                            Button(action: { showDeleteConfirmation = true }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "trash.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.red)
                                        .frame(width: 20)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Delete Restaurant Data")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.red)
                                        Text("Hide restaurant from public search immediately")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color.white.opacity(0.6))
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color.white.opacity(0.4))
                                }
                                .padding(16)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // Logout Button
                        Button(action: onLogout) {
                            Text("Log Out")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(hex: "f87171"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(hex: "ef4444").opacity(0.1))
                                .cornerRadius(20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color(hex: "ef4444").opacity(0.3), lineWidth: 1)
                                )
                        }
                        .padding(.bottom, 120)
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: 500)
                }
            }
        }
        .onAppear {
            loadSettingsData()
            actionHandler.saveAction = {
                await performSave()
            }
            actionHandler.discardAction = {
                discardChanges()
            }
        }
        .sheet(item: $activeEditField) { field in
            EditFieldSheet(
                field: field,
                restaurantName: $restaurantName,
                restaurantDescription: $restaurantDescription,
                restaurantCuisine: $restaurantCuisine,
                restaurantPhone: $restaurantPhone,
                restaurantAddress: $restaurantAddress,
                restaurantCity: $restaurantCity,
                restaurantPincode: $restaurantPincode,
                ownerName: $ownerName,
                ownerPhone: $ownerPhone
            )
        }
        .sheet(isPresented: $showHoursEditor) {
            HoursEditorSheet(openingHours: $openingHours, daysOfWeek: daysOfWeek)
        }
        .alert("Delete Restaurant?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteRestaurant()
            }
        } message: {
            Text("Are you sure you want to delete your restaurant? It will be hidden from search immediately, and permanently purged in 30 days.")
        }
        .onChange(of: selectedLogoItem) { newItem in
            guard let newItem = newItem else { return }
            isUploadingLogo = true
            Task {
                do {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        let filename = "\(UUID().uuidString)"
                        let url = try await SupabaseManager.shared.uploadLogo(data: data, name: filename)
                        await MainActor.run {
                            self.logoUrl = url
                            self.isUploadingLogo = false
                        }
                    } else {
                        await MainActor.run { self.isUploadingLogo = false }
                    }
                } catch {
                    await MainActor.run {
                        self.isUploadingLogo = false
                        self.errorMessage = "Failed to upload logo: \(error.localizedDescription)"
                    }
                }
            }
        }
        .onChange(of: selectedGalleryItem) { newItem in
            guard let newItem = newItem else { return }
            if galleryUrls.count >= 5 {
                errorMessage = "Maximum 5 gallery images allowed"
                return
            }
            isUploadingGallery = true
            Task {
                do {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        let filename = "\(UUID().uuidString)"
                        let url = try await SupabaseManager.shared.uploadImage(data: data, name: filename)
                        await MainActor.run {
                            self.galleryUrls.append(url)
                            self.isUploadingGallery = false
                        }
                    } else {
                        await MainActor.run { self.isUploadingGallery = false }
                    }
                } catch {
                    await MainActor.run {
                        self.isUploadingGallery = false
                        self.errorMessage = "Failed to upload gallery photo: \(error.localizedDescription)"
                    }
                }
            }
        }
        .onChange(of: restaurantName) { _ in hasUnsavedChangesBinding = hasUnsavedChanges }
        .onChange(of: restaurantDescription) { _ in hasUnsavedChangesBinding = hasUnsavedChanges }
        .onChange(of: restaurantCuisine) { _ in hasUnsavedChangesBinding = hasUnsavedChanges }
        .onChange(of: restaurantPhone) { _ in hasUnsavedChangesBinding = hasUnsavedChanges }
        .onChange(of: restaurantAddress) { _ in hasUnsavedChangesBinding = hasUnsavedChanges }
        .onChange(of: restaurantCity) { _ in hasUnsavedChangesBinding = hasUnsavedChanges }
        .onChange(of: restaurantPincode) { _ in hasUnsavedChangesBinding = hasUnsavedChanges }
        .onChange(of: logoUrl) { _ in hasUnsavedChangesBinding = hasUnsavedChanges }
        .onChange(of: galleryUrls) { _ in hasUnsavedChangesBinding = hasUnsavedChanges }
        .onChange(of: openingHours) { _ in hasUnsavedChangesBinding = hasUnsavedChanges }
        .onChange(of: ownerName) { _ in hasUnsavedChangesBinding = hasUnsavedChanges }
        .onChange(of: ownerPhone) { _ in hasUnsavedChangesBinding = hasUnsavedChanges }
    }
    
    private func loadSettingsData() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // 1. Fetch Owner's Restaurant
                let rest = try await SupabaseManager.shared.fetchOwnerRestaurant()
                
                // 2. Fetch Owner's Profile
                guard let userId = SupabaseManager.shared.currentUser?.id else { return }
                let profile = try await SupabaseManager.shared.fetchProfile(userId: userId)
                
                await MainActor.run {
                    self.restaurantName = rest.name
                    self.restaurantDescription = rest.description ?? ""
                    self.restaurantCuisine = rest.cuisine_type ?? ""
                    self.restaurantPhone = rest.phone ?? ""
                    self.restaurantAddress = rest.address ?? ""
                    self.restaurantCity = rest.city ?? ""
                    self.restaurantPincode = rest.pincode ?? ""
                    self.logoUrl = rest.logo_url ?? ""
                    self.galleryUrls = rest.gallery_urls ?? []
                    self.openingHours = rest.opening_hours ?? [:]
                    
                    self.ownerName = profile.full_name ?? ""
                    self.accountEmail = profile.email ?? SupabaseManager.shared.currentUser?.email ?? ""
                    self.ownerPhone = profile.phone ?? ""
                    
                    // Capture original values for change detection
                    self.originalRestaurantName = self.restaurantName
                    self.originalRestaurantDescription = self.restaurantDescription
                    self.originalRestaurantCuisine = self.restaurantCuisine
                    self.originalRestaurantPhone = self.restaurantPhone
                    self.originalRestaurantAddress = self.restaurantAddress
                    self.originalRestaurantCity = self.restaurantCity
                    self.originalRestaurantPincode = self.restaurantPincode
                    self.originalLogoUrl = self.logoUrl
                    self.originalGalleryUrls = self.galleryUrls
                    self.originalOpeningHours = self.openingHours
                    self.originalOwnerName = self.ownerName
                    self.originalOwnerPhone = self.ownerPhone
                    
                    self.isLoading = false
                    self.hasUnsavedChangesBinding = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load settings: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    @discardableResult
    private func performSave() async -> Bool {
        await MainActor.run {
            isSaving = true
            errorMessage = nil
        }
        
        do {
            try await SupabaseManager.shared.updateRestaurant(
                name: restaurantName,
                description: restaurantDescription,
                cuisineType: restaurantCuisine,
                phone: restaurantPhone,
                address: restaurantAddress,
                city: restaurantCity,
                pincode: restaurantPincode,
                logoUrl: logoUrl.isEmpty ? nil : logoUrl,
                galleryUrls: galleryUrls,
                openingHours: openingHours
            )
            
            try await SupabaseManager.shared.updateProfile(
                role: "owner",
                roles: nil,
                fullName: ownerName,
                restaurantName: restaurantName,
                logoURL: logoUrl.isEmpty ? nil : logoUrl,
                cuisine: restaurantCuisine,
                address: restaurantAddress,
                phone: restaurantPhone,
                city: restaurantCity,
                pincode: restaurantPincode,
                fssai: nil,
                openingHours: nil,
                bio: restaurantDescription
            )
            
            await MainActor.run {
                // Update original values
                self.originalRestaurantName = self.restaurantName
                self.originalRestaurantDescription = self.restaurantDescription
                self.originalRestaurantCuisine = self.restaurantCuisine
                self.originalRestaurantPhone = self.restaurantPhone
                self.originalRestaurantAddress = self.restaurantAddress
                self.originalRestaurantCity = self.restaurantCity
                self.originalRestaurantPincode = self.restaurantPincode
                self.originalLogoUrl = self.logoUrl
                self.originalGalleryUrls = self.galleryUrls
                self.originalOpeningHours = self.openingHours
                self.originalOwnerName = self.ownerName
                self.originalOwnerPhone = self.ownerPhone
                
                self.hasUnsavedChangesBinding = false
                self.isSaving = false
                ToastManager.shared.show("Settings saved successfully!")
            }
            return true
        } catch {
            await MainActor.run {
                self.isSaving = false
                self.errorMessage = "Failed to save settings: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    private func saveAllSettings() {
        Task {
            await performSave()
        }
    }
    
    private func discardChanges() {
        self.restaurantName = self.originalRestaurantName
        self.restaurantDescription = self.originalRestaurantDescription
        self.restaurantCuisine = self.originalRestaurantCuisine
        self.restaurantPhone = self.originalRestaurantPhone
        self.restaurantAddress = self.originalRestaurantAddress
        self.restaurantCity = self.originalRestaurantCity
        self.restaurantPincode = self.originalRestaurantPincode
        self.logoUrl = self.originalLogoUrl
        self.galleryUrls = self.originalGalleryUrls
        self.openingHours = self.originalOpeningHours
        self.ownerName = self.originalOwnerName
        self.ownerPhone = self.originalOwnerPhone
        self.hasUnsavedChangesBinding = false
    }
    
    private var hasUnsavedChanges: Bool {
        restaurantName != originalRestaurantName ||
        restaurantDescription != originalRestaurantDescription ||
        restaurantCuisine != originalRestaurantCuisine ||
        restaurantPhone != originalRestaurantPhone ||
        restaurantAddress != originalRestaurantAddress ||
        restaurantCity != originalRestaurantCity ||
        restaurantPincode != originalRestaurantPincode ||
        logoUrl != originalLogoUrl ||
        galleryUrls != originalGalleryUrls ||
        openingHours != originalOpeningHours ||
        ownerName != originalOwnerName ||
        ownerPhone != originalOwnerPhone
    }
    
    
    private func deleteRestaurant() {
        isLoading = true
        Task {
            do {
                try await SupabaseManager.shared.softDeleteRestaurant()
                await MainActor.run {
                    isLoading = false
                    onLogout() // logout on successful delete
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to delete: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Subviews & Sheets

struct EditFieldSheet: View {
    let field: EditField
    @Binding var restaurantName: String
    @Binding var restaurantDescription: String
    @Binding var restaurantCuisine: String
    @Binding var restaurantPhone: String
    @Binding var restaurantAddress: String
    @Binding var restaurantCity: String
    @Binding var restaurantPincode: String
    @Binding var ownerName: String
    @Binding var ownerPhone: String
    
    @Environment(\.dismiss) var dismiss
    
    // Local working states to allow cancellation
    @State private var tempName = ""
    @State private var tempDescription = ""
    @State private var tempCuisine = ""
    @State private var tempPhone = ""
    @State private var tempAddress = ""
    @State private var tempCity = ""
    @State private var tempPincode = ""
    @State private var tempOwnerName = ""
    @State private var tempOwnerPhone = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            switch field {
                            case .restaurantName:
                                GlassInput(label: "Restaurant Name", text: $tempName, icon: "storefront.fill", placeholder: "The Golden Fork")
                            case .cuisineType:
                                GlassInput(label: "Cuisine Type", text: $tempCuisine, icon: "sparkles", placeholder: "e.g. Italian, Fast Food")
                            case .phone:
                                GlassInput(label: "Phone Number", text: $tempPhone, icon: "phone.fill", placeholder: "+1 (555) 123-4567", keyboardType: .phonePad)
                            case .address:
                                GlassInput(label: "Street Address", text: $tempAddress, icon: "mappin.and.ellipse", placeholder: "123 Main St")
                                HStack(spacing: 12) {
                                    GlassInput(label: "City", text: $tempCity, icon: "building.2.fill", placeholder: "New York")
                                    GlassInput(label: "Pincode", text: $tempPincode, icon: "number.square.fill", placeholder: "10001", keyboardType: .numberPad)
                                }
                            case .description:
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Description / Bio")
                                        .font(.subheadline)
                                        .foregroundColor(Theme.textSecondary)
                                    TextEditor(text: $tempDescription)
                                        .foregroundColor(.white)
                                        .padding(12)
                                        .frame(height: 150)
                                        .background(Color.white.opacity(0.05))
                                        .cornerRadius(16)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                        )
                                }
                            case .ownerName:
                                GlassInput(label: "Owner Name", text: $tempOwnerName, icon: "person.fill", placeholder: "John Doe")
                                GlassInput(label: "Owner Phone Number", text: $tempOwnerPhone, icon: "phone.fill", placeholder: "+1 (555) 987-6543", keyboardType: .phonePad)
                            }
                        }
                        .padding(24)
                    }
                    Spacer()
                }
            }
            .navigationTitle(titleForField)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundColor(Theme.primaryBlue)
                }
            }
            .onAppear {
                tempName = restaurantName
                tempDescription = restaurantDescription
                tempCuisine = restaurantCuisine
                tempPhone = restaurantPhone
                tempAddress = restaurantAddress
                tempCity = restaurantCity
                tempPincode = restaurantPincode
                tempOwnerName = ownerName
                tempOwnerPhone = ownerPhone
            }
        }
    }
    
    var titleForField: String {
        switch field {
        case .restaurantName: return "Edit Restaurant Name"
        case .cuisineType: return "Edit Cuisine Type"
        case .phone: return "Edit Phone Number"
        case .address: return "Edit Address"
        case .description: return "Edit Description"
        case .ownerName: return "Edit Owner Details"
        }
    }
    
    func saveChanges() {
        switch field {
        case .restaurantName: restaurantName = tempName
        case .cuisineType: restaurantCuisine = tempCuisine
        case .phone: restaurantPhone = tempPhone
        case .address:
            restaurantAddress = tempAddress
            restaurantCity = tempCity
            restaurantPincode = tempPincode
        case .description: restaurantDescription = tempDescription
        case .ownerName:
            ownerName = tempOwnerName
            ownerPhone = tempOwnerPhone
        }
    }
}

struct HoursEditorSheet: View {
    @Binding var openingHours: [String: OpeningHourDay]
    let daysOfWeek: [(id: String, label: String)]
    @Environment(\.dismiss) var dismiss
    
    @State private var tempHours: [String: OpeningHourDay] = [:]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                List {
                    ForEach(daysOfWeek, id: \.id) { day in
                        let hours = tempHours[day.id] ?? OpeningHourDay(open: "09:00", close: "22:00", isClosed: false)
                        
                        SwiftUI.Section(header: Text(day.label)) {
                            Toggle("Closed Today", isOn: Binding(
                                get: { hours.isClosed ?? false },
                                set: { newValue in
                                    tempHours[day.id] = OpeningHourDay(
                                        open: hours.open,
                                        close: hours.close,
                                        isClosed: newValue
                                    )
                                }
                            ))
                            .tint(.blue)
                            
                            if !(hours.isClosed ?? false) {
                                DatePicker("Open Time", selection: Binding(
                                    get: { dateFromTimeString(hours.open ?? "09:00") },
                                    set: { newDate in
                                        tempHours[day.id] = OpeningHourDay(
                                            open: timeStringFromDate(newDate),
                                            close: hours.close,
                                            isClosed: false
                                        )
                                    }
                                ), displayedComponents: .hourAndMinute)
                                
                                DatePicker("Close Time", selection: Binding(
                                    get: { dateFromTimeString(hours.close ?? "22:00") },
                                    set: { newDate in
                                        tempHours[day.id] = OpeningHourDay(
                                            open: hours.open,
                                            close: timeStringFromDate(newDate),
                                            isClosed: false
                                        )
                                    }
                                ), displayedComponents: .hourAndMinute)
                            }
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Edit Opening Hours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        openingHours = tempHours
                        dismiss()
                    }.fontWeight(.bold).foregroundColor(Theme.primaryBlue)
                }
            }
            .onAppear {
                tempHours = openingHours
            }
        }
    }
    
    private func dateFromTimeString(_ timeStr: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.date(from: timeStr) ?? Date()
    }
    
    private func timeStringFromDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Helper Views for Settings UI

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(Theme.primaryBlue)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                content
            }
            .buttonStyle(PlainButtonStyle())
            .background(Color(hex: "1e293b").opacity(0.4))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let label: String
    let value: String
    var showChevron: Bool = true
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Theme.primaryBlue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.6))
                Text(value)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(Color.white.opacity(0.4))
            }
        }
        .padding(16)
        .contentShape(Rectangle())
    }
}

struct CustomToggle: View {
    @Binding var isOn: Bool
    
    var body: some View {
        Toggle("", isOn: $isOn)
            .labelsHidden()
            .tint(Theme.primaryBlue)
    }
}

struct NotificationToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            Spacer()
            CustomToggle(isOn: $isOn)
        }
    }
}
