import SwiftUI

struct OwnerLoginScreen: View {
    // Callbacks
    var onLogin: () -> Void
    var onSignup: () -> Void
    var onForgotPassword: () -> Void
    var onBack: () -> Void
    
    // State
    @State private var email: String = ""
    @State private var password: String = ""
    
    var body: some View {
        ZStack {
            // 1. Unified Liquid Glass Background
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
                            .shadow(color: Theme.primaryBlue.opacity(0.3), radius: 32, x: 0, y: 8)
                        
                        Text("🏪")
                            .font(.system(size: 32))
                    }
                    
                    Text("Restaurant Owner Login")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Sign in to manage your restaurant")
                        .font(.body)
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(.bottom, 48)
                
                // Form
                VStack(spacing: 24) {
                    GlassInput(
                        label: "Email Address",
                        text: $email,
                        icon: "envelope.fill",
                        placeholder: "owner@restaurant.com",
                        keyboardType: .emailAddress
                    )
                    
                    GlassInput(
                        label: "Password",
                        text: $password,
                        icon: "lock.fill",
                        placeholder: "Enter your password",
                        isSecure: true
                    )
                    
                    HStack {
                        Spacer()
                        Button(action: onForgotPassword) {
                            Text("Forgot Password?")
                                .font(.subheadline)
                                .foregroundColor(Theme.primaryBlue)
                        }
                    }
                    
                    Button(action: onLogin) {
                        HStack(spacing: 8) {
                            Text("Sign In")
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
                
                // Signup Link
                Button(action: onSignup) {
                    Text("Don't have an account? ")
                        .foregroundColor(Theme.textSecondary) +
                    Text("Sign Up")
                        .fontWeight(.bold)
                        .foregroundColor(Theme.primaryBlue)
                }
                
                Spacer()
            }
        }
    }
}
