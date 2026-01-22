import SwiftUI

struct RootView: View {
    @StateObject private var authManager = SupabaseManager.shared
    @State private var showOwnerFlow = false
    @State private var showSignup = false
    
    var body: some View {
        Group {
            if showOwnerFlow {
                OwnerTabView()
                    .transition(.opacity)
            } else {
                HomeView(
                    onSwitchToOwner: {
                        withAnimation {
                            showOwnerFlow = true
                        }
                    },
                    onLogout: {
                        withAnimation {
                            authManager.isAuthenticated = false
                            showOwnerFlow = false
                        }
                    }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: authManager.isAuthenticated)
        .animation(.easeInOut, value: showOwnerFlow)
        .animation(.easeInOut, value: showSignup)
        .onChange(of: authManager.isAuthenticated) { isAuthenticated in
            if !isAuthenticated {
                showOwnerFlow = false
            } else if let user = authManager.currentUser, user.email == "rest@gmail.com" { // Or proper role check
                 // Optional: Auto-navigate to owner flow on login if appropriate
                 // For now, let's just ensure logout takes us home.
                 showOwnerFlow = true
            }
        }
        .environment(AppDataModel.instance)
    }
}
