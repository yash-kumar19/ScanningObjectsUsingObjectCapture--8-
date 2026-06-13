import SwiftUI

struct RootView: View {
    @ObservedObject private var authManager = SupabaseManager.shared
    @StateObject private var toastManager = ToastManager.shared
    
    // Mode-based state
    @State private var isOwnerMode = false
    @State private var isCheckingRestaurant = false
    @State private var showOnboarding = false
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            if isOwnerMode {
                OwnerTabView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
            } else {
                HomeView(
                    onSwitchToOwner: {
                         withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                             isOwnerMode = true
                         }
                    },
                    onLogout: {
                         authManager.logout()
                    }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(0)
            }
            
            // Checking Restaurant or Restoring Session Overlay
            if isCheckingRestaurant || authManager.isRestoringSession {
                VStack(spacing: 24) {
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .fill(Theme.primaryBlue.opacity(0.15))
                            .frame(width: 120, height: 120)
                            .blur(radius: 10)
                        
                        Circle()
                            .stroke(LinearGradient(colors: [Theme.primaryBlue, Theme.primaryPurple], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 3)
                            .frame(width: 90, height: 90)
                        
                        Image(systemName: "storefront.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(LinearGradient(colors: [Theme.primaryBlue, Theme.primaryPurple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                    
                    VStack(spacing: 12) {
                        Text("Welcome to Seedish")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text(authManager.isRestoringSession ? "Resuming your session..." : "Checking your restaurant...")
                            .font(.headline)
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.background.ignoresSafeArea())
                .zIndex(10)
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isOwnerMode)
        .onChange(of: authManager.isAuthenticated) { authenticated in
            if authenticated {
                if authManager.loginIntent == .owner {
                    checkRestaurantAndSwitch()
                } else {
                    validateAndSwitch()
                }
            } else {
                withAnimation(.spring(response: 0.4, dampingFraction: 1.0)) {
                    isOwnerMode = false
                }
            }
        }
        .onChange(of: authManager.userRole) { role in
            if authManager.isAuthenticated {
                if authManager.loginIntent == .owner {
                    checkRestaurantAndSwitch()
                } else {
                    validateAndSwitch()
                }
            }
        }
        .onChange(of: authManager.isRestoringSession) { isRestoring in
            if !isRestoring && authManager.isAuthenticated {
                validateAndSwitch()
            }
        }
        .onAppear {
            // Initial validation for cold start
            if authManager.isAuthenticated {
                validateAndSwitch()
            }
        }
        .environment(AppDataModel.instance)
        .fullScreenCover(isPresented: $showOnboarding) {
            RestaurantOnboardingScreen(
                onComplete: {
                    showOnboarding = false
                    authManager.userRole = "owner"
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        isOwnerMode = true
                    }
                },
                onBack: {
                    showOnboarding = false
                    authManager.logout()
                }
            )
        }
        .overlay(
            ToastView(manager: toastManager)
        )
    }
    
    private func checkRestaurantAndSwitch() {
        authManager.loginIntent = .none
        
        withAnimation(.easeIn(duration: 0.2)) {
            isCheckingRestaurant = true
        }
        
        Task {
            let startTime = Date()
            
            // Check restaurant existence
            var hasRestaurant = false
            do {
                _ = try await authManager.fetchOwnerRestaurant()
                hasRestaurant = true
            } catch {
                print("Checking restaurant failed: \(error.localizedDescription)")
                hasRestaurant = false
            }
            
            // Ensure visual checking is shown for at least 1.0 second
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed < 1.0 {
                try? await Task.sleep(nanoseconds: UInt64((1.0 - elapsed) * 1_000_000_000))
            }
            
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) {
                    isCheckingRestaurant = false
                }
                
                if hasRestaurant {
                    authManager.userRole = "owner"
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        isOwnerMode = true
                    }
                } else {
                    showOnboarding = true
                }
            }
        }
    }
    
    private func validateAndSwitch() {
        if authManager.isOwner {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isOwnerMode = true
            }
        } else {
            // Keep customer in customer mode (or owner switched to customer mode)
            // DO NOT log them out, allowing persistent customer sessions.
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isOwnerMode = false
            }
        }
    }
}
