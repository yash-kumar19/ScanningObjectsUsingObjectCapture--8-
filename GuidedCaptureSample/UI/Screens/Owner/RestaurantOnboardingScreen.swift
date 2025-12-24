import SwiftUI
import PhotosUI

struct RestaurantOnboardingScreen: View {
    var onComplete: () -> Void
    var onBack: () -> Void
    
    @State private var restaurantName = ""
    @State private var ownerName = ""
    @State private var phone = ""
    @State private var address = ""
    @State private var city = ""
    @State private var pincode = ""
    @State private var fssai = ""
    @State private var cuisine = ""
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: Image?
    
    @State private var isHeaderVisible = false
    @State private var isFormVisible = false
    @State private var showSuccess = false
    
    let cuisineTypes = [
        "Indian", "Chinese", "Italian", "Mexican", "Japanese",
        "Thai", "Mediterranean", "American", "Fast Food", "Cafe"
    ]
    
    var body: some View {
        ZStack {
            // 1. Background Gradient
            LinearGradient(
                colors: [
                    Color(hex: "050505"),
                    Color(hex: "0B0F1A"),
                    Color(hex: "111827")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // 2. Background Glow Blob
            VStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "8b5cf6").opacity(0.4), Color(hex: "2b7fff").opacity(0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 300
                        )
                    )
                    .frame(width: 380, height: 380)
                    .blur(radius: 120)
                    .offset(y: -300)
                Spacer()
            }
            .ignoresSafeArea()
            
            // 3. Content
            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 20)
                    
                    // Back Button
                    HStack {
                        Button(action: onBack) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.left")
                                Text("Back")
                            }
                            .foregroundColor(Color.white.opacity(0.6))
                        }
                        Spacer()
                    }
                    .padding(.bottom, 20)
                    
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Restaurant Details")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Tell us about your restaurant to get started")
                            .font(.body)
                            .foregroundColor(Color.white.opacity(0.6))
                        
                        // Progress Indicator
                        HStack(spacing: 8) {
                            Capsule()
                                .fill(Color(hex: "2b7fff"))
                                .frame(height: 4)
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 4)
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 4)
                        }
                        .padding(.top, 16)
                        
                        Text("Step 1 of 3")
                            .font(.caption)
                            .foregroundColor(Color.white.opacity(0.4))
                    }
                    .padding(.bottom, 32)
                    .offset(y: isHeaderVisible ? 0 : 20)
                    .opacity(isHeaderVisible ? 1 : 0)
                    
                    // Form
                    VStack(spacing: 24) {
                        // Logo Upload
                        GlassCard(padding: 24) {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Restaurant Logo")
                                    .foregroundColor(.white)
                                
                                HStack(spacing: 16) {
                                    // Preview
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(Color.white.opacity(0.05))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                                                    .foregroundColor(Color.white.opacity(0.15))
                                            )
                                        
                                        if let selectedImage = selectedImage {
                                            selectedImage
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 96, height: 96)
                                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                        } else {
                                            Image(systemName: "storefront.fill")
                                                .font(.system(size: 32))
                                                .foregroundColor(Color.white.opacity(0.4))
                                        }
                                    }
                                    .frame(width: 96, height: 96)
                                    
                                    // Upload Button
                                    VStack(alignment: .leading, spacing: 8) {
                                        PhotosPicker(selection: $selectedItem, matching: .images) {
                                            HStack(spacing: 8) {
                                                Image(systemName: "square.and.arrow.up")
                                                Text("Upload Logo")
                                            }
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 24)
                                            .padding(.vertical, 12)
                                            .background(Color.white.opacity(0.05))
                                            .cornerRadius(16)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                            )
                                        }
                                        
                                        Text("PNG or JPG, max 5MB")
                                            .font(.caption)
                                            .foregroundColor(Color.white.opacity(0.4))
                                    }
                                }
                            }
                        }
                        
                        // Restaurant Information
                        GlassCard(padding: 24) {
                            VStack(alignment: .leading, spacing: 20) {
                                Text("Restaurant Information")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                CustomTextField(icon: "storefront.fill", label: "Restaurant Name *", placeholder: "The Golden Fork", text: $restaurantName)
                                
                                // Cuisine Type Dropdown (Simulated with Menu or Picker)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Cuisine Type *")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color.white.opacity(0.8))
                                    
                                    Menu {
                                        ForEach(cuisineTypes, id: \.self) { type in
                                            Button(type) {
                                                cuisine = type
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Image(systemName: "doc.text.fill")
                                                .foregroundColor(Color.white.opacity(0.4))
                                            
                                            Text(cuisine.isEmpty ? "Select cuisine type" : cuisine)
                                                .foregroundColor(cuisine.isEmpty ? Color.white.opacity(0.4) : .white)
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.down")
                                                .foregroundColor(Color.white.opacity(0.4))
                                        }
                                        .padding(14)
                                        .background(Color.white.opacity(0.05))
                                        .cornerRadius(16)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                        )
                                    }
                                }
                            }
                        }
                        
                        // Owner Information
                        GlassCard(padding: 24) {
                            VStack(alignment: .leading, spacing: 20) {
                                Text("Owner Information")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                CustomTextField(icon: "person.fill", label: "Owner Name *", placeholder: "John Doe", text: $ownerName)
                                CustomTextField(icon: "phone.fill", label: "Phone Number *", placeholder: "+1 (555) 123-4567", text: $phone, keyboardType: .phonePad)
                            }
                        }
                        
                        // Location
                        GlassCard(padding: 24) {
                            VStack(alignment: .leading, spacing: 20) {
                                Text("Location")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                CustomTextField(icon: "mappin.and.ellipse", label: "Address *", placeholder: "123 Main Street, Suite 100", text: $address)
                                
                                HStack(spacing: 12) {
                                    CustomTextField(label: "City *", placeholder: "New York", text: $city)
                                    CustomTextField(label: "Pincode *", placeholder: "10001", text: $pincode, keyboardType: .numberPad)
                                }
                            }
                        }
                        
                        // FSSAI
                        GlassCard(padding: 24) {
                            VStack(alignment: .leading, spacing: 20) {
                                CustomTextField(icon: "doc.text.fill", label: "FSSAI / GST Number *", placeholder: "Enter license number", text: $fssai)
                                Text("Required for restaurant verification")
                                    .font(.caption)
                                    .foregroundColor(Color.white.opacity(0.4))
                            }
                        }
                        
                        // Submit Button
                        PrimaryButton(title: "Complete Setup", fullWidth: true) {
                            showSuccess = true
                        }
                        .padding(.bottom, 40)
                    }
                    .offset(y: isFormVisible ? 0 : 20)
                    .opacity(isFormVisible ? 1 : 0)
                }
                .frame(maxWidth: 500) // Max width constraint
                .padding(.horizontal, 24) // Standard padding
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
        }
        .fullScreenCover(isPresented: $showSuccess) {
            OnboardingSuccessScreen(
                onContinue: {
                    showSuccess = false
                    onComplete() // This will trigger the switch to Owner Dashboard in ProfileScreen
                }
            )
        }
        .onChange(of: selectedItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    selectedImage = Image(uiImage: uiImage)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                isHeaderVisible = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                isFormVisible = true
            }
        }
    }
}

// Helper Component for Text Fields
struct CustomTextField: View {
    var icon: String?
    var label: String
    var placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(Color.white.opacity(0.8))
            
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundColor(Color.white.opacity(0.4))
                }
                
                TextField("", text: $text)
                    .placeholder(when: text.isEmpty) {
                        Text(placeholder).foregroundColor(Color.white.opacity(0.4))
                    }
                    .foregroundColor(.white)
                    .keyboardType(keyboardType)
            }
            .padding(14)
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }
}
