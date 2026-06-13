import SwiftUI

// MARK: - BookingSheet

struct BookingSheet: View {
    let ownerId: String
    let restaurantName: String
    var onDismiss: () -> Void
    var onSuccess: () -> Void
    
    @Binding var isPresented: Bool
    @ObservedObject private var authManager = SupabaseManager.shared
    
    // Reservation Details State
    @State private var guestCount = 2
    @State private var selectedDate = Date()
    @State private var specialRequest = ""
    
    // Contact Info State (for non-logged in guests)
    @State private var customerName = ""
    @State private var email = ""
    @State private var localPhone = ""
    @State private var selectedCountry: PhoneCountry = phoneCountries[0]
    @State private var showCountryPicker = false
    
    // OTP State
    @State private var otpCode = ""
    @State private var isCodeSent = false
    
    // UI State
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var nameError: String?
    @State private var phoneError: String?
    @State private var emailError: String?
    @State private var otpError: String?
    
    // MARK: - Computed
    
    private var e164Phone: String {
        let digits = localPhone.filter { $0.isNumber }
        return "\(selectedCountry.dialCode)\(digits)"
    }
    
    private var isFormValid: Bool {
        let nameOK = customerName.trimmingCharacters(in: .whitespaces).count >= 2
        let digits = localPhone.filter { $0.isNumber }
        let phoneOK = digits.count >= 7 && digits.count <= 15
        
        let emailOK: Bool
        if authManager.isAuthenticated {
            emailOK = true
        } else {
            let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
            let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
            emailOK = emailPred.evaluate(with: email.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        return nameOK && phoneOK && emailOK
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0F172A").ignoresSafeArea()
                
                if !isCodeSent {
                    Form {
                        SwiftUI.Section(header: Text("Reservation Details").foregroundColor(.gray)) {
                            DatePicker("Date & Time", selection: $selectedDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                                .colorScheme(.dark)
                            
                            Stepper("Guests: \(guestCount)", value: $guestCount, in: 1...20)
                                .foregroundColor(.white)
                        }
                        .listRowBackground(Color(hex: "1E293B"))
                        
                        SwiftUI.Section(header: Text("Contact Details").foregroundColor(.gray)) {
                            if authManager.isAuthenticated {
                                HStack {
                                    Text("Logged In")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Text(email)
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                }
                            } else {
                                TextField("Full Name", text: $customerName)
                                    .foregroundColor(.white)
                                    .autocorrectionDisabled()
                                
                                TextField("Email Address", text: $email)
                                    .keyboardType(.emailAddress)
                                    .foregroundColor(.white)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                
                                HStack {
                                    Button(action: { showCountryPicker = true }) {
                                        HStack(spacing: 4) {
                                            Text(selectedCountry.flag)
                                            Text(selectedCountry.dialCode)
                                                .foregroundColor(.white)
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 8))
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    
                                    TextField(selectedCountry.example, text: $localPhone)
                                        .keyboardType(.numberPad)
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .listRowBackground(Color(hex: "1E293B"))
                        
                        SwiftUI.Section(header: Text("Special Request").foregroundColor(.gray)) {
                            TextField("Any allergies or special occasions?", text: $specialRequest)
                                .foregroundColor(.white)
                        }
                        .listRowBackground(Color(hex: "1E293B"))
                        
                        if let error = errorMessage {
                            SwiftUI.Section {
                                Text(error)
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                            .listRowBackground(Color.clear)
                        }
                        
                        SwiftUI.Section {
                            Button(action: handleBookingAction) {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(authManager.isAuthenticated ? "Confirm Booking" : "Verify Email & Book")
                                        .frame(maxWidth: .infinity)
                                        .font(.headline)
                                        .foregroundColor(.blue)
                                }
                            }
                            .disabled(isLoading || (!authManager.isAuthenticated && !isFormValid))
                        }
                        .listRowBackground(Color(hex: "1E293B"))
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color(hex: "0F172A"))
                } else {
                    // OTP Verification Code Entry
                    VStack(spacing: 24) {
                        Text("Verify Your Identity")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("We've sent a 6-digit confirmation code to \(email). Please enter it below to complete your booking.")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("6-Digit Verification Code")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                            
                            TextField("••••••", text: $otpCode)
                                .keyboardType(.numberPad)
                                .font(.system(size: 24, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(16)
                                .background(Color(hex: "1E293B"))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(otpError != nil ? Color.red.opacity(0.6) : Color.white.opacity(0.1), lineWidth: 1)
                                )
                                .onChange(of: otpCode) { _ in otpError = nil }
                        }
                        .frame(maxWidth: 300)
                        
                        if let error = otpError {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                        
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Button(action: verifyOTPAndBook) {
                                Text("Verify & Confirm Booking")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 18)
                                    .background(LinearGradient(colors: [Color(hex: "10B981"), Color(hex: "059669")], startPoint: .leading, endPoint: .trailing))
                                    .cornerRadius(16)
                                    .shadow(color: Color(hex: "10B981").opacity(0.4), radius: 12, x: 0, y: 6)
                            }
                            .disabled(otpCode.count < 6)
                            .padding(.horizontal, 24)
                            
                            Button(action: {
                                isCodeSent = false
                                otpCode = ""
                                otpError = nil
                            }) {
                                Text("Go Back & Edit Details")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.primaryBlue)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 40)
                    Spacer()
                }
            }
            .navigationTitle("Book a Table")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            if authManager.isAuthenticated, let user = authManager.currentUser {
                email = user.email ?? ""
                customerName = ""
                Task {
                    if let profile = try? await SupabaseManager.shared.fetchProfile(userId: user.id) {
                        await MainActor.run {
                            customerName = profile.full_name ?? ""
                            if let phone = profile.phone {
                                for country in phoneCountries {
                                    if phone.hasPrefix(country.dialCode) {
                                        selectedCountry = country
                                        localPhone = String(phone.dropFirst(country.dialCode.count))
                                        break
                                    }
                                }
                                if localPhone.isEmpty {
                                    localPhone = phone
                                }
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showCountryPicker) {
            CountryPickerSheet(selectedCountry: $selectedCountry)
        }
    }
    
    private func handleBookingAction() {
        if authManager.isAuthenticated {
            submitBooking()
        } else {
            // Validate first
            let trimmedName = customerName.trimmingCharacters(in: .whitespaces)
            guard trimmedName.count >= 2 else {
                errorMessage = "Please enter your name"
                return
            }
            
            let digits = localPhone.filter { $0.isNumber }
            guard digits.count >= 7 && digits.count <= 15 else {
                errorMessage = "Please enter a valid phone number"
                return
            }
            
            isLoading = true
            errorMessage = nil
            
            Task {
                do {
                    try await SupabaseManager.shared.sendOTP(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
                    await MainActor.run {
                        isLoading = false
                        isCodeSent = true
                    }
                } catch {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = "Failed to send code: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    private func verifyOTPAndBook() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let code = otpCode.trimmingCharacters(in: .whitespacesAndNewlines)
        
        isLoading = true
        otpError = nil
        
        Task {
            do {
                try await SupabaseManager.shared.verifyOTP(email: trimmedEmail, token: code)
                
                // Add name/phone to profile
                let userId = SupabaseManager.shared.currentUser?.id ?? ""
                var profileRoles = ["customer"]
                if let profile = try? await SupabaseManager.shared.fetchProfile(userId: userId) {
                    profileRoles = profile.roles ?? ["customer"]
                }
                
                try? await SupabaseManager.shared.updateProfile(
                    role: "customer",
                    roles: profileRoles,
                    fullName: customerName,
                    restaurantName: nil,
                    logoURL: nil,
                    cuisine: nil,
                    address: nil,
                    phone: e164Phone,
                    city: nil,
                    pincode: nil,
                    fssai: nil,
                    openingHours: nil,
                    bio: nil
                )
                
                await MainActor.run {
                    submitBooking()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    otpError = "Invalid or expired code. Please try again."
                }
            }
        }
    }
    
    private func submitBooking() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await SupabaseManager.shared.createReservation(
                    ownerId: ownerId,
                    guests: guestCount,
                    date: selectedDate,
                    special: specialRequest.isEmpty ? nil : specialRequest
                )
                
                await MainActor.run {
                    isLoading = false
                    onSuccess()
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to book table: \(error.localizedDescription)"
                }
            }
        }
    }
}
