import SwiftUI

struct SignupScreen: View {
    var onSignupSuccess: () -> Void
    var onBackToLogin: () -> Void
    
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // Animations
    @State private var isLogoVisible = false
    @State private var isTextVisible = false
    @State private var isFormVisible = false
    
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
            
            // 2. Background Glow Blob (Purple/Blue for Signup)
            VStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "8b5cf6").opacity(0.3), Color(hex: "2b7fff").opacity(0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 300
                        )
                    )
                    .frame(width: 380, height: 380) // Reduced from 600
                    .blur(radius: 120)
                    .offset(y: -200)
                Spacer()
            }
            .ignoresSafeArea()
            
            // 3. Content
            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 20)
                    
                    // Back Button
                    HStack {
                        Button(action: onBackToLogin) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.left")
                                Text("Back to Login")
                            }
                            .foregroundColor(Color.white.opacity(0.6))
                        }
                        Spacer()
                    }
                    .padding(.bottom, 20)
                    .opacity(isLogoVisible ? 1 : 0)
                    
                    // Logo & Header
                    VStack(spacing: 24) {
                        // Logo
                        ZStack {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "2b7fff"), Color(hex: "8b5cf6")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                                .shadow(color: Color(hex: "2b7fff").opacity(0.4), radius: 60, x: 0, y: 20)
                            
                            Text("🍽️")
                                .font(.system(size: 40))
                        }
                        .scaleEffect(isLogoVisible ? 1 : 0.8)
                        .opacity(isLogoVisible ? 1 : 0)
                        
                        VStack(spacing: 12) {
                            Text("Create Account")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Join FoodView 3D today and start\nexploring menus in a new dimension.")
                                .font(.body)
                                .foregroundColor(Color.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                        }
                        .offset(y: isTextVisible ? 0 : 10)
                        .opacity(isTextVisible ? 1 : 0)
                    }
                    .padding(.bottom, 32)
                    
                    // Signup Form
                    GlassCard(padding: 32) {
                        VStack(spacing: 24) {
                            // Name Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Full Name")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.white.opacity(0.8))
                                
                                HStack {
                                    Image(systemName: "person")
                                        .foregroundColor(Color.white.opacity(0.4))
                                    
                                    TextField("", text: $name)
                                        .placeholder(when: name.isEmpty) {
                                            Text("John Doe").foregroundColor(Color.white.opacity(0.4))
                                        }
                                        .foregroundColor(.white)
                                        .textContentType(.name)
                                        .autocapitalization(.words)
                                }
                                .padding(14)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                            }
                            
                            // Email Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.white.opacity(0.8))
                                
                                HStack {
                                    Image(systemName: "envelope")
                                        .foregroundColor(Color.white.opacity(0.4))
                                    
                                    TextField("", text: $email)
                                        .placeholder(when: email.isEmpty) {
                                            Text("your@email.com").foregroundColor(Color.white.opacity(0.4))
                                        }
                                        .foregroundColor(.white)
                                        .textContentType(.emailAddress)
                                        .keyboardType(.emailAddress)
                                        .autocapitalization(.none)
                                }
                                .padding(14)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                            }
                            
                            // Password Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.white.opacity(0.8))
                                
                                HStack {
                                    Image(systemName: "lock")
                                        .foregroundColor(Color.white.opacity(0.4))
                                    
                                    if showPassword {
                                        TextField("", text: $password)
                                            .placeholder(when: password.isEmpty) {
                                                Text("Create a password").foregroundColor(Color.white.opacity(0.4))
                                            }
                                            .foregroundColor(.white)
                                    } else {
                                        SecureField("", text: $password)
                                            .placeholder(when: password.isEmpty) {
                                                Text("Create a password").foregroundColor(Color.white.opacity(0.4))
                                            }
                                            .foregroundColor(.white)
                                    }
                                    
                                    Button(action: { showPassword.toggle() }) {
                                        Image(systemName: showPassword ? "eye.slash" : "eye")
                                            .foregroundColor(Color.white.opacity(0.4))
                                    }
                                }
                                .padding(14)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                                
                                Text("Must be at least 8 characters")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.white.opacity(0.4))
                            }
                            
                            // Create Account Button
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                PrimaryButton(title: "Create Account", fullWidth: true) {
                                    handleSignup()
                                }
                            }
                            
                            // Divider
                            HStack(spacing: 16) {
                                Rectangle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 1)
                                Text("Or continue with")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.white.opacity(0.6))
                                    .fixedSize(horizontal: true, vertical: false)
                                Rectangle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 1)
                            }
                            .padding(.vertical, 8)
                            
                            // Social Login
                            HStack(spacing: 12) {
                                SocialButton(icon: "g.circle.fill", label: "Google") {
                                    if let url = SupabaseManager.shared.getOAuthURL(provider: "google") {
                                        UIApplication.shared.open(url)
                                    }
                                }
                                SocialButton(icon: "apple.logo", label: "Apple") {
                                    // Apple Auth implementation
                                }
                            }
                            
                            // Login Link
                            HStack(spacing: 4) {
                                Text("Already have an account?")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.white.opacity(0.6))
                                
                                Button("Log In") {
                                    onBackToLogin()
                                }
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "2b7fff"))
                            }
                            .padding(.top, 8)
                        }
                    }
                    .offset(y: isFormVisible ? 0 : 20)
                    .opacity(isFormVisible ? 1 : 0)
                    
                    // Footer
                    Text("By continuing, you agree to our Terms and Privacy Policy.")
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.4))
                        .padding(.top, 24)
                        .opacity(isFormVisible ? 1 : 0)
                    
                    // Bottom spacer for scrolling
                    Spacer().frame(height: 20)
                }
                .frame(maxWidth: 500) // Prevent stretching
                .padding(.horizontal, 24) // Standard padding
                .padding(.bottom, 120) // Ensure content clears Tab Bar
            }
            .scrollIndicators(.hidden)
            
            // Error Toast
            if let error = errorMessage {
                VStack {
                    Spacer()
                    Text(error)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red.opacity(0.9))
                        .cornerRadius(12)
                        .padding(.bottom, 130) // Increased to clear Tab Bar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .onTapGesture {
                    withAnimation {
                        errorMessage = nil
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                isLogoVisible = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                isTextVisible = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.4)) {
                isFormVisible = true
            }
        }
    }
    
    private func handleSignup() {
        guard !name.isEmpty, !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all fields"
            return
        }
        
        if password.count < 8 {
            errorMessage = "Password must be at least 8 characters"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await SupabaseManager.shared.signup(email: email, password: password)
                await MainActor.run {
                    isLoading = false
                    onSignupSuccess()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
