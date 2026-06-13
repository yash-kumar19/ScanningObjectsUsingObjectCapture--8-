//
//  CustomerInfoSheet.swift
//  GuidedCaptureSample
//

import SwiftUI

// MARK: - Country Model

struct PhoneCountry: Identifiable {
    let id: String
    let flag: String
    let name: String
    let dialCode: String
    
    /// Minimum local digits for this country (7–15 range accepted globally)
    var example: String
}

let phoneCountries: [PhoneCountry] = [
    PhoneCountry(id: "IN", flag: "🇮🇳", name: "India",         dialCode: "+91",  example: "9876543210"),
    PhoneCountry(id: "US", flag: "🇺🇸", name: "United States", dialCode: "+1",   example: "2025551234"),
    PhoneCountry(id: "GB", flag: "🇬🇧", name: "United Kingdom",dialCode: "+44",  example: "7911123456"),
    PhoneCountry(id: "AU", flag: "🇦🇺", name: "Australia",     dialCode: "+61",  example: "412345678"),
    PhoneCountry(id: "SG", flag: "🇸🇬", name: "Singapore",     dialCode: "+65",  example: "91234567"),
    PhoneCountry(id: "AE", flag: "🇦🇪", name: "UAE",           dialCode: "+971", example: "501234567"),
    PhoneCountry(id: "CA", flag: "🇨🇦", name: "Canada",        dialCode: "+1",   example: "6135550100"),
]

// MARK: - CustomerInfoSheet

struct CustomerInfoSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var authManager = SupabaseManager.shared
    
    // Prefilled values (from caller)
    var prefillName: String = ""
    
    // Callbacks
    var onConfirm: (String, String, String?) -> Void  // (name, e164Phone, specialNotes?)
    
    // Form state
    @State private var customerName: String = ""
    @State private var localPhone: String = ""
    @State private var email: String = ""
    @State private var specialNotes: String = ""
    @State private var selectedCountry: PhoneCountry = phoneCountries[0]  // Default: India
    @State private var showCountryPicker = false
    
    // OTP State
    @State private var otpCode: String = ""
    @State private var isCodeSent = false
    @State private var cooldownSeconds = 0
    
    // UI state
    @State private var isSubmitting = false
    @State private var nameError: String? = nil
    @State private var phoneError: String? = nil
    @State private var emailError: String? = nil
    @State private var otpError: String? = nil
    
    // MARK: - Computed
    
    private var e164Phone: String {
        let digits = localPhone.filter { $0.isNumber }
        return "\(selectedCountry.dialCode)\(digits)"
    }
    
    private var isValid: Bool {
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
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            Color(hex: "0F172A").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Drag handle
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 40, height: 4)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                
                // Header
                HStack(alignment: .center) {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.12))
                                .frame(width: 36, height: 36)
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text(isCodeSent ? "Verify Email" : "Your Details")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    // Balance spacer
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                
                if !isCodeSent {
                    ScrollView {
                        VStack(spacing: 20) {
                            // MARK: Name Field
                            fieldBlock(label: "Full Name", error: nameError) {
                                TextField("Enter your name", text: $customerName)
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .padding(16)
                                    .background(Color(hex: "1E293B"))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(nameError != nil ? Color.red.opacity(0.6) : Color.white.opacity(0.1), lineWidth: 1)
                                    )
                                    .onChange(of: customerName) { _ in nameError = nil }
                            }
                            
                            // MARK: Email Field
                            if authManager.isAuthenticated {
                                fieldBlock(label: "Email Address (Verified)", error: nil) {
                                    Text(email)
                                        .font(.system(size: 16))
                                        .foregroundColor(.white.opacity(0.6))
                                        .padding(16)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(hex: "1E293B").opacity(0.5))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                                        )
                                }
                            } else {
                                fieldBlock(label: "Email Address", error: emailError) {
                                    TextField("Enter your email", text: $email)
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                        .padding(16)
                                        .background(Color(hex: "1E293B"))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(emailError != nil ? Color.red.opacity(0.6) : Color.white.opacity(0.1), lineWidth: 1)
                                        )
                                        .onChange(of: email) { _ in emailError = nil }
                                        .keyboardType(.emailAddress)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                }
                            }
                            
                            // MARK: Phone Field
                            fieldBlock(label: "Phone Number", error: phoneError) {
                                HStack(spacing: 0) {
                                    Button(action: { showCountryPicker = true }) {
                                        HStack(spacing: 6) {
                                            Text(selectedCountry.flag)
                                                .font(.system(size: 20))
                                            Text(selectedCountry.dialCode)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(.white)
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundColor(.white.opacity(0.5))
                                        }
                                        .padding(.horizontal, 14)
                                        .frame(height: 50)
                                        .background(Color(hex: "273450"))
                                        .cornerRadius(12, corners: [.topLeft, .bottomLeft])
                                    }
                                    
                                    Rectangle()
                                        .fill(Color.white.opacity(0.1))
                                        .frame(width: 1, height: 32)
                                    
                                    TextField(selectedCountry.example, text: $localPhone)
                                        .keyboardType(.numberPad)
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 14)
                                        .frame(height: 50)
                                        .frame(maxWidth: .infinity)
                                        .onChange(of: localPhone) { _ in phoneError = nil }
                                }
                                .background(Color(hex: "1E293B"))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(phoneError != nil ? Color.red.opacity(0.6) : Color.white.opacity(0.1), lineWidth: 1)
                                )
                            }
                            
                            // MARK: Special Notes
                            fieldBlock(label: "Special Instructions (Optional)", error: nil) {
                                TextEditor(text: $specialNotes)
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)
                                    .scrollContentBackground(.hidden)
                                    .frame(height: 80)
                                    .padding(12)
                                    .background(Color(hex: "1E293B"))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            }
                            
                            if !localPhone.filter({ $0.isNumber }).isEmpty {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: "10B981"))
                                    Text("Will be stored as \(e164Phone)")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 140)
                    }
                    
                    // MARK: Place Order Button
                    VStack {
                        Button(action: handleAction) {
                            HStack {
                                if isSubmitting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.9)
                                    Text("Processing...")
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 18))
                                    Text(authManager.isAuthenticated ? "Confirm & Place Order" : "Verify Email & Checkout")
                                        .font(.system(size: 17, weight: .bold))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                isSubmitting || !isValid
                                ? LinearGradient(colors: [Color.gray.opacity(0.5), Color.gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [Color(hex: "3B82F6"), Color(hex: "2563EB")], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(16)
                            .shadow(color: isValid ? Color(hex: "3B82F6").opacity(0.4) : .clear, radius: 12, x: 0, y: 6)
                        }
                        .disabled(isSubmitting || !isValid)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                } else {
                    // OTP Verification Code Entry
                    VStack(spacing: 24) {
                        Text("Verify Your Identity")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("We've sent a 6-digit confirmation code to \(email). Please enter it below to complete your order.")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        fieldBlock(label: "6-Digit Verification Code", error: otpError) {
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
                        
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Button(action: verifyOTPAndConfirm) {
                                Text("Verify & Confirm Order")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 18)
                                    .background(LinearGradient(colors: [Color(hex: "10B981"), Color(hex: "059669")], startPoint: .leading, endPoint: .trailing))
                                    .cornerRadius(16)
                                    .shadow(color: Color(hex: "10B981").opacity(0.4), radius: 12, x: 0, y: 6)
                            }
                            .disabled(otpCode.count < 6)
                            
                            if cooldownSeconds > 0 {
                                Text("Resend code in \(cooldownSeconds)s")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.5))
                                    .padding(.top, 4)
                            } else {
                                Button(action: resendOTPCode) {
                                    Text("Didn't get it? Resend code")
                                        .font(.subheadline)
                                        .foregroundColor(Theme.primaryBlue)
                                        .padding(.top, 4)
                                }
                            }
                            
                            Button(action: {
                                isCodeSent = false
                                otpCode = ""
                                otpError = nil
                            }) {
                                Text("Go Back & Edit Details")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.primaryBlue)
                                    .padding(.top, 8)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 40)
                    Spacer()
                }
            }
        }
        .onAppear {
            customerName = prefillName
            if authManager.isAuthenticated, let user = authManager.currentUser {
                email = user.email ?? ""
                Task {
                    if let profile = try? await SupabaseManager.shared.fetchProfile(userId: user.id) {
                        await MainActor.run {
                            if customerName.isEmpty {
                                customerName = profile.full_name ?? ""
                            }
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
    
    // MARK: - Helpers
    
    @ViewBuilder
    private func fieldBlock<Content: View>(label: String, error: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
            content()
            if let error = error {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundColor(Color.red.opacity(0.8))
            }
        }
    }
    
    private func startCooldown() {
        cooldownSeconds = 30
        Task {
            while cooldownSeconds > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    if cooldownSeconds > 0 {
                        cooldownSeconds -= 1
                    }
                }
            }
        }
    }
    
    private func handleAction() {
        // Form validations
        let trimmedName = customerName.trimmingCharacters(in: .whitespaces)
        guard trimmedName.count >= 2 else {
            nameError = "Please enter your full name (min 2 characters)"
            return
        }
        
        let digits = localPhone.filter { $0.isNumber }
        guard digits.count >= 7 && digits.count <= 15 else {
            phoneError = "Please enter a valid phone number (7–15 digits)"
            return
        }
        
        if authManager.isAuthenticated {
            // Instant checkout since customer is already authenticated
            submit()
        } else {
            // Trigger OTP sign-in in the background
            isSubmitting = true
            otpError = nil
            
            Task {
                do {
                    try await SupabaseManager.shared.sendOTP(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
                    await MainActor.run {
                        isSubmitting = false
                        isCodeSent = true
                        startCooldown()
                    }
                } catch {
                    await MainActor.run {
                        isSubmitting = false
                        emailError = "Failed to send verification code. Check your address."
                    }
                }
            }
        }
    }
    
    private func resendOTPCode() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else { return }
        
        isSubmitting = true
        otpError = nil
        otpCode = ""
        
        Task {
            do {
                try await SupabaseManager.shared.sendOTP(email: trimmedEmail)
                await MainActor.run {
                    isSubmitting = false
                    startCooldown()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    otpError = "Failed to send verification code. Check your address."
                }
            }
        }
    }
    
    private func verifyOTPAndConfirm() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let code = otpCode.trimmingCharacters(in: .whitespacesAndNewlines)
        
        isSubmitting = true
        otpError = nil
        
        Task {
            do {
                try await SupabaseManager.shared.verifyOTP(email: trimmedEmail, token: code)
                
                // Add name/phone to profile since we just signed up/in
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
                    isSubmitting = false
                    submit()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    otpError = "Invalid or expired code. Please try again."
                }
            }
        }
    }
    
    private func submit() {
        isSubmitting = true
        let notes = specialNotes.trimmingCharacters(in: .whitespaces)
        onConfirm(customerName, e164Phone, notes.isEmpty ? nil : notes)
    }
}

// MARK: - Country Picker Sheet

struct CountryPickerSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedCountry: PhoneCountry
    
    var body: some View {
        ZStack {
            Color(hex: "0F172A").ignoresSafeArea()
            
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 40, height: 4)
                    .padding(.vertical, 16)
                
                Text("Select Country")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.bottom, 16)
                
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(phoneCountries) { country in
                            Button(action: {
                                selectedCountry = country
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                HStack(spacing: 14) {
                                    Text(country.flag)
                                        .font(.system(size: 24))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(country.name)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(.white)
                                        Text(country.dialCode)
                                            .font(.system(size: 13))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                    Spacer()
                                    if country.id == selectedCountry.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Color(hex: "3B82F6"))
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .background(country.id == selectedCountry.id ? Color.white.opacity(0.05) : Color.clear)
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}
