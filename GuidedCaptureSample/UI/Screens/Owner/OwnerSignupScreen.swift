import SwiftUI

struct OwnerSignupScreen: View {
    // Callbacks
    var onSignup: () -> Void
    var onLogin: () -> Void
    var onBack: () -> Void
    
    // State
    @State private var restaurantName: String = ""
    @State private var ownerName: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var showPassword: Bool = false
    @State private var showConfirmPassword: Bool = false
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            // Background Glows
            // Glow removed per user request
            
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
                VStack(spacing: 12) {
                    Text("Create Restaurant Account")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Join thousands of restaurants using 3D menus")
                        .font(.body)
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(.bottom, 32)
                
                // Form
                ScrollView {
                    VStack(spacing: 24) {
                        GlassInput(
                            label: "Restaurant Name",
                            text: $restaurantName,
                            icon: "storefront.fill",
                            placeholder: "The Golden Fork"
                        )
                        
                        GlassInput(
                            label: "Your Name",
                            text: $ownerName,
                            icon: "person.fill",
                            placeholder: "John Doe"
                        )
                        
                        GlassInput(
                            label: "Email Address",
                            text: $email,
                            icon: "envelope.fill",
                            placeholder: "owner@restaurant.com",
                            keyboardType: .emailAddress
                        )
                        
                        // Password with Toggle
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                            
                            HStack(spacing: 12) {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(Theme.textSecondary)
                                
                                if showPassword {
                                    TextField("Create a strong password", text: $password)
                                        .foregroundColor(.white)
                                        .accentColor(Theme.primaryBlue)
                                } else {
                                    SecureField("Create a strong password", text: $password)
                                        .foregroundColor(.white)
                                        .accentColor(Theme.primaryBlue)
                                }
                                
                                Button(action: { showPassword.toggle() }) {
                                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(Theme.textSecondary)
                                }
                            }
                            .padding(16)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        }
                        
                        // Confirm Password with Toggle
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Confirm Password")
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                            
                            HStack(spacing: 12) {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(Theme.textSecondary)
                                
                                if showConfirmPassword {
                                    TextField("Confirm your password", text: $confirmPassword)
                                        .foregroundColor(.white)
                                        .accentColor(Theme.primaryBlue)
                                } else {
                                    SecureField("Confirm your password", text: $confirmPassword)
                                        .foregroundColor(.white)
                                        .accentColor(Theme.primaryBlue)
                                }
                                
                                Button(action: { showConfirmPassword.toggle() }) {
                                    Image(systemName: showConfirmPassword ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(Theme.textSecondary)
                                }
                            }
                            .padding(16)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        }
                        
                        Button(action: onSignup) {
                            HStack(spacing: 8) {
                                Text("Create Account")
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
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
                
                // Login Link
                Button(action: onLogin) {
                    Text("Already have an account? ")
                        .foregroundColor(Theme.textSecondary) +
                    Text("Sign In")
                        .fontWeight(.bold)
                        .foregroundColor(Theme.primaryBlue)
                }
                .padding(.bottom, 24)
            }
        }
    }
}
