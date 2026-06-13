import SwiftUI

struct OwnerLoginScreen: View {
    // Callbacks
    var onLogin: () -> Void
    var onBack: () -> Void
    
    // State
    @State private var email: String = ""
    @State private var otpCode: String = ""
    @State private var isCodeSent = false
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var cooldownSeconds = 0
    
    var body: some View {
        ZStack {
            // 1. Unified Background
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Back Button
                HStack {
                    Button(action: onBack) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.left")
                            Text("Back")
                        }
                        .foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 32)
                
                // Header
                VStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(LinearGradient(colors: [Theme.primaryBlue.opacity(0.2), Theme.primaryPurple.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 80, height: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Theme.primaryBlue.opacity(0.4), lineWidth: 1)
                            )
                        
                        Image(systemName: "storefront.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(LinearGradient(colors: [Theme.primaryBlue, Theme.primaryPurple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                    
                    Text("Restaurant Partner Portal")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(isCodeSent ? "Enter the code sent to \(email)" : "Enter your email to receive a sign-in code")
                        .font(.body)
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.bottom, 32)
                
                // Form
                VStack(spacing: 24) {
                    if !isCodeSent {
                        // Email State
                        GlassInput(
                            label: "Email Address",
                            text: $email,
                            icon: "envelope.fill",
                            placeholder: "owner@restaurant.com",
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
                                    Image(systemName: "paperplane.fill")
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
                    } else {
                        // Verification Code State
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
                            
                            if cooldownSeconds > 0 {
                                Text("Resend code in \(cooldownSeconds)s")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textSecondary)
                                    .padding(.top, 8)
                            } else {
                                Button(action: resendCode) {
                                    Text("Didn't get it? Resend code")
                                        .font(.subheadline)
                                        .foregroundColor(Theme.primaryBlue)
                                        .padding(.top, 8)
                                }
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
                }
                .padding(.horizontal, 24)
                
                Spacer()
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
    
    private func sendCode() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            errorMessage = "Please enter your email address"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await SupabaseManager.shared.sendOTP(email: trimmedEmail)
                await MainActor.run {
                    isLoading = false
                    isCodeSent = true
                    startCooldown()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func resendCode() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        otpCode = ""
        
        Task {
            do {
                try await SupabaseManager.shared.sendOTP(email: trimmedEmail)
                await MainActor.run {
                    isLoading = false
                    startCooldown()
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
        
        Task {
            do {
                try await SupabaseManager.shared.verifyOTP(email: trimmedEmail, token: trimmedCode)
                await MainActor.run {
                    isLoading = false
                    onLogin()
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
        SupabaseManager.shared.loginIntent = .owner
        if let url = SupabaseManager.shared.getOAuthURL(provider: provider) {
            UIApplication.shared.open(url)
        }
    }
}
