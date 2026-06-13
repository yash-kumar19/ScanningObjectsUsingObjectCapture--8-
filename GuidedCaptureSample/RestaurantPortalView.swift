import SwiftUI

struct RestaurantPortalView: View {
    @ObservedObject private var authManager = SupabaseManager.shared
    
    var onLogin: () -> Void
    var onSignup: () -> Void
    var onGoToDashboard: () -> Void
    
    @State private var email: String = ""
    @State private var otpCode: String = ""
    @State private var isCodeSent = false
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    
    var isOwner: Bool {
        authManager.isOwner
    }
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            // Background Decorative elements
            backgroundGlow
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    // Hero Section
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Theme.primaryBlue.opacity(0.15))
                                .frame(width: 80, height: 80)
                                .blur(radius: 20)
                            
                            Image(systemName: "storefront.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(Theme.gradientBlue)
                        }
                        .padding(.top, 60)
                        
                        Text("For Restaurant Owners")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.primaryBlue)
                            .tracking(2)
                            .textCase(.uppercase)
                        
                        Text("Run your restaurant with 3D menus")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        
                        Text("Manage dishes, orders & AR models in one powerful dashboard.")
                            .font(.system(size: 16))
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    
                    // Features Grid
                    VStack(spacing: 20) {
                        PortalFeatureRow(
                            icon: "cube.transparent.fill",
                            title: "3D Photogrammetry",
                            description: "Convert photos of your dishes into high-quality 3D models automatically."
                        )
                        
                        PortalFeatureRow(
                            icon: "chart.bar.fill",
                            title: "Order Management",
                            description: "Track and manage incoming orders from your customers in real-time."
                        )
                        
                        PortalFeatureRow(
                            icon: "arkit",
                            title: "AR Experiences",
                            description: "Give your customers an immersive way to visualize food on their table."
                        )
                    }
                    .padding(.horizontal, 24)
                    
                    // Action Section
                    VStack(spacing: 16) {
                        if isOwner {
                            // High Impact Dashboard Button
                            Button(action: onGoToDashboard) {
                                HStack {
                                    Text("Go to Owner Dashboard")
                                        .font(.headline)
                                    Spacer()
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.title2)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .frame(height: 70)
                                .background(Theme.gradientBlue)
                                .cornerRadius(20)
                                .shadow(color: Theme.primaryBlue.opacity(0.3), radius: 20, x: 0, y: 10)
                            }
                            
                            Text("You are currently logged in as an owner.")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        } else {
                            // Unified Partner Login Form directly on the screen
                            VStack(spacing: 20) {
                                if !isCodeSent {
                                    // Step 1: Email Input
                                    GlassInput(
                                        label: "Email Address",
                                        text: $email,
                                        icon: "envelope.fill",
                                        placeholder: "you@restaurant.com",
                                        keyboardType: .emailAddress
                                    )
                                    
                                    if let error = errorMessage {
                                        Text(error)
                                            .foregroundColor(.red)
                                            .font(.caption)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal)
                                    }
                                    
                                    if isLoading {
                                        ProgressView()
                                            .tint(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 16)
                                            .background(Theme.gradientBlue)
                                            .cornerRadius(20)
                                    } else {
                                        Button(action: sendCode) {
                                            HStack(spacing: 8) {
                                                Text("Send Sign-In Code")
                                                Image(systemName: "arrow.right")
                                            }
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 16)
                                            .background(Theme.gradientBlue)
                                            .cornerRadius(20)
                                            .shadow(color: Theme.primaryBlue.opacity(0.4), radius: 16, x: 0, y: 8)
                                        }
                                    }
                                } else {
                                    // Step 2: OTP Verification
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("6-Digit Code")
                                            .font(.subheadline)
                                            .foregroundColor(Theme.textSecondary)
                                        
                                        TextField("••••••", text: $otpCode)
                                            .keyboardType(.numberPad)
                                            .foregroundColor(.white)
                                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                                            .multilineTextAlignment(.center)
                                            .accentColor(Theme.primaryBlue)
                                            .padding(16)
                                            .background(
                                                Color(hex: "1e293b"),
                                                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                            )
                                            .onChange(of: otpCode) { _ in
                                                errorMessage = nil
                                            }
                                    }
                                    
                                    if let error = errorMessage {
                                        Text(error)
                                            .foregroundColor(.red)
                                            .font(.caption)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal)
                                    }
                                    
                                    if isLoading {
                                        ProgressView()
                                            .tint(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 16)
                                            .background(Theme.gradientBlue)
                                            .cornerRadius(20)
                                    } else {
                                        Button(action: verifyCode) {
                                            HStack(spacing: 8) {
                                                Text("Verify & Sign In")
                                                Image(systemName: "checkmark.circle.fill")
                                            }
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 16)
                                            .background(Theme.gradientBlue)
                                            .cornerRadius(20)
                                            .shadow(color: Theme.primaryBlue.opacity(0.4), radius: 16, x: 0, y: 8)
                                        }
                                        
                                        Button(action: {
                                            isCodeSent = false
                                            otpCode = ""
                                            errorMessage = nil
                                        }) {
                                            Text("Use a different email")
                                                .font(.subheadline)
                                                .foregroundColor(Theme.primaryBlue)
                                                .padding(.top, 8)
                                        }
                                    }
                                }
                                
                                // Divider
                                HStack {
                                    Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                                    Text("or continue with")
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                        .padding(.horizontal, 8)
                                    Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                                }
                                .padding(.vertical, 8)
                                
                                // OAuth Options
                                VStack(spacing: 12) {
                                    // Google
                                    Button(action: { loginWithOAuth(provider: "google") }) {
                                        HStack(spacing: 12) {
                                            Text("G")
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundColor(Theme.primaryBlue)
                                            Text("Continue with Google")
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(Color.white.opacity(0.05))
                                        .cornerRadius(16)
                                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
                                    }
                                    
                                    // Apple
                                    Button(action: { loginWithOAuth(provider: "apple") }) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "apple.logo")
                                                .foregroundColor(.white)
                                            Text("Continue with Apple")
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(Color.white.opacity(0.05))
                                        .cornerRadius(16)
                                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                    
                    // Bottom Padding for Tab Bar
                    Color.clear.frame(height: 120)
                }
            }
        }
    }
    
    private func sendCode() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            errorMessage = "Please enter your email address"
            return
        }
        
        isLoading = true
        errorMessage = nil
        authManager.loginIntent = .owner
        
        Task {
            do {
                try await authManager.sendOTP(email: trimmedEmail)
                await MainActor.run {
                    isLoading = false
                    isCodeSent = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func verifyCode() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCode = otpCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCode.isEmpty else {
            errorMessage = "Please enter the verification code"
            return
        }
        
        isLoading = true
        errorMessage = nil
        authManager.loginIntent = .owner
        
        Task {
            do {
                try await authManager.verifyOTP(email: trimmedEmail, token: trimmedCode)
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Invalid or expired code. Please try again."
                }
            }
        }
    }
    
    private func loginWithOAuth(provider: String) {
        authManager.loginIntent = .owner
        if let url = authManager.getOAuthURL(provider: provider) {
            UIApplication.shared.open(url)
        }
    }
    
    private var backgroundGlow: some View {
        ZStack {
            Circle()
                .fill(Theme.primaryBlue.opacity(0.1))
                .frame(width: 400, height: 400)
                .blur(radius: 100)
                .offset(x: -150, y: -200)
            
            Circle()
                .fill(Theme.primaryPurple.opacity(0.05))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: 150, y: 300)
        }
    }
}

struct PortalFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 56, height: 56)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(Theme.primaryBlue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.white.opacity(0.02))
        .cornerRadius(20)
    }
}

#Preview {
    RestaurantPortalView(onLogin: {}, onSignup: {}, onGoToDashboard: {})
}
