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
        .environment(AppDataModel.instance)
    }
}
