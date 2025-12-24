import SwiftUI

struct OwnerTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.background.ignoresSafeArea()
            
            // Content
            Group {
                switch selectedTab {
                case 0:
                    OwnerDashboardScreen()
                case 1:
                    OwnerMenuScreen()
                case 2:
                    OwnerGeneratorScreen()
                case 3:
                    OwnerReservationsScreen()
                case 4:
                    OwnerSettingsScreen(onLogout: {})
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
            OwnerBottomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard)
    }
}

struct OwnerBottomTabBar: View {
    @Binding var selectedTab: Int
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: 0) {
            OwnerTabBarItem(
                icon: "square.grid.2x2.fill",
                title: "Dashboard",
                index: 0,
                selectedTab: $selectedTab,
                animation: animation
            )
            
            OwnerTabBarItem(
                icon: "list.bullet",
                title: "Menu",
                index: 1,
                selectedTab: $selectedTab,
                animation: animation
            )
            
            OwnerTabBarItem(
                icon: "wand.and.stars",
                title: "Generator",
                index: 2,
                selectedTab: $selectedTab,
                animation: animation
            )
            
            OwnerTabBarItem(
                icon: "calendar",
                title: "Bookings",
                index: 3,
                selectedTab: $selectedTab,
                animation: animation
            )
            
            OwnerTabBarItem(
                icon: "gearshape.fill",
                title: "Settings",
                index: 4,
                selectedTab: $selectedTab,
                animation: animation
            )
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .fixedSize(horizontal: false, vertical: true)
        .background(
            ZStack {
                // Blur
                BlurView(style: .systemUltraThinMaterialDark)
                
                // Black tint (bg-black/80)
                Color.black.opacity(0.8)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.6), radius: 32, x: 0, y: 8)
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }
}

struct OwnerTabBarItem: View {
    let icon: String
    let title: String
    let index: Int
    @Binding var selectedTab: Int
    let animation: Namespace.ID
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                selectedTab = index
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
