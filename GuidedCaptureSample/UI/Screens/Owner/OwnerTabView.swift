import SwiftUI

class SettingsActionHandler: ObservableObject {
    var saveAction: (() async -> Bool)?
    var discardAction: (() -> Void)?
}

struct OwnerTabView: View {
    @State private var selectedTab = 0
    @State private var settingsHasChanges = false
    @State private var showUnsavedChangesAlert = false
    @State private var pendingTab = 0
    @StateObject private var settingsActionHandler = SettingsActionHandler()
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.background.ignoresSafeArea()
            
            // Content
            Group {
                switch selectedTab {
                case 0:
                    OwnerDashboardScreen(onTabSelect: { tabIndex in
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            selectedTab = tabIndex
                        }
                    })
                case 1:
                    OwnerMenuScreen()
                case 2:
                    OwnerGeneratorScreen()
                case 3:
                    OwnerOrdersScreen()
                case 4:
                    OwnerSettingsScreen(
                        onLogout: {
                            SupabaseManager.shared.logout()
                        },
                        hasUnsavedChangesBinding: $settingsHasChanges,
                        actionHandler: settingsActionHandler
                    )
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .id(selectedTab)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                removal: .opacity.combined(with: .scale(scale: 1.05))
            ))
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedTab)
            
            // Custom Bottom Tab Bar for Owner
            OwnerBottomTabBar(
                selectedTab: $selectedTab,
                settingsHasChanges: $settingsHasChanges,
                showUnsavedChangesAlert: $showUnsavedChangesAlert,
                pendingTab: $pendingTab
            )
        }
        .ignoresSafeArea(.keyboard)
        .alert("Unsaved Changes", isPresented: $showUnsavedChangesAlert) {
            Button("Save Changes") {
                Task {
                    if let handler = settingsActionHandler.saveAction {
                        let success = await handler()
                        if success {
                            settingsHasChanges = false
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                selectedTab = pendingTab
                            }
                        }
                    }
                }
            }
            Button("Discard Changes", role: .destructive) {
                settingsActionHandler.discardAction?()
                settingsHasChanges = false
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    selectedTab = pendingTab
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You have unsaved changes in settings. Would you like to save them before leaving?")
        }
    }
}

struct OwnerBottomTabBar: View {
    @Binding var selectedTab: Int
    @Binding var settingsHasChanges: Bool
    @Binding var showUnsavedChangesAlert: Bool
    @Binding var pendingTab: Int
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: 0) {
            OwnerTabBarItem(
                icon: "square.grid.2x2.fill",
                title: "Dashboard",
                index: 0,
                selectedTab: $selectedTab,
                settingsHasChanges: $settingsHasChanges,
                showUnsavedChangesAlert: $showUnsavedChangesAlert,
                pendingTab: $pendingTab,
                animation: animation
            )
            
            OwnerTabBarItem(
                icon: "list.bullet",
                title: "Menu",
                index: 1,
                selectedTab: $selectedTab,
                settingsHasChanges: $settingsHasChanges,
                showUnsavedChangesAlert: $showUnsavedChangesAlert,
                pendingTab: $pendingTab,
                animation: animation
            )
            
            OwnerTabBarItem(
                icon: "wand.and.stars",
                title: "Generator",
                index: 2,
                selectedTab: $selectedTab,
                settingsHasChanges: $settingsHasChanges,
                showUnsavedChangesAlert: $showUnsavedChangesAlert,
                pendingTab: $pendingTab,
                animation: animation
            )
            
            OwnerTabBarItem(
                icon: "tray.fill",
                title: "Orders",
                index: 3,
                selectedTab: $selectedTab,
                settingsHasChanges: $settingsHasChanges,
                showUnsavedChangesAlert: $showUnsavedChangesAlert,
                pendingTab: $pendingTab,
                animation: animation
            )
            
            OwnerTabBarItem(
                icon: "gearshape.fill",
                title: "Settings",
                index: 4,
                selectedTab: $selectedTab,
                settingsHasChanges: $settingsHasChanges,
                showUnsavedChangesAlert: $showUnsavedChangesAlert,
                pendingTab: $pendingTab,
                animation: animation
            )
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .fixedSize(horizontal: false, vertical: true)
        .background(
            Color(hex: "1e293b"),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.15),
                            .white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }
}

struct OwnerTabBarItem: View {
    let icon: String
    let title: String
    let index: Int
    @Binding var selectedTab: Int
    @Binding var settingsHasChanges: Bool
    @Binding var showUnsavedChangesAlert: Bool
    @Binding var pendingTab: Int
    let animation: Namespace.ID
    
    var body: some View {
        Button {
            if selectedTab == 4 && index != 4 && settingsHasChanges {
                pendingTab = index
                showUnsavedChangesAlert = true
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    selectedTab = index
                }
            }
        } label: {
            ZStack {
                // Active Background Pill
                if selectedTab == index {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "2b7fff").opacity(0.2),
                                    Color(hex: "3b82f6").opacity(0.2)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color(hex: "2b7fff").opacity(0.4), lineWidth: 1)
                        )
                        .shadow(color: Color(hex: "2b7fff").opacity(0.2), radius: 16, x: 0, y: 4)
                        .matchedGeometryEffect(id: "OWNER_TAB_BG", in: animation)
                }
                
                // Icon + Text
                VStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 20)) // Slightly smaller for 5 items
                        .foregroundColor(selectedTab == index ? Color(hex: "2b7fff") : Color.white.opacity(0.6))
                    
                    Text(title)
                        .font(.system(size: 10, weight: .medium)) // Smaller text for 5 items
                        .foregroundColor(selectedTab == index ? Color(hex: "2b7fff") : Color.white.opacity(0.6))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .padding(.vertical, 8)
                .frame(maxWidth: 80) // Slightly narrower for 5 items
                .frame(minHeight: 52)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}
