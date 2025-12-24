import SwiftUI

struct BottomTabBar: View {
    @Binding var selectedTab: Int
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: 0) {
            TabBarItem(
                icon: "house",
                title: "Home",
                index: 0,
                selectedTab: $selectedTab,
                animation: animation
            )
            
            TabBarItem(
                icon: "magnifyingglass",
                title: "Search",
                index: 1,
                selectedTab: $selectedTab,
                animation: animation
            )
            
            TabBarItem(
                icon: "calendar",
                title: "Bookings",
                index: 2,
                selectedTab: $selectedTab,
                animation: animation
            )
            
            TabBarItem(
                icon: "person",
                title: "Profile",
                index: 3,
                selectedTab: $selectedTab,
                animation: animation
            )
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .fixedSize(horizontal: false, vertical: true) // Prevent vertical stretching
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

struct TabBarItem: View {
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
                        .matchedGeometryEffect(id: "TAB_BG", in: animation)
                }
                
                // Icon + Text
                VStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 24)) // w-6 h-6 = 24px
                        .foregroundColor(selectedTab == index ? Color(hex: "2b7fff") : Color.white.opacity(0.6))
                    
                    Text(title)
                        .font(.system(size: 12, weight: .medium)) // text-xs = 12px
                        .foregroundColor(selectedTab == index ? Color(hex: "2b7fff") : Color.white.opacity(0.6))
                }
                .padding(.vertical, 8)
                .frame(maxWidth: 100) // max-w-[100px]
                .frame(minHeight: 52) // min-h-[52px]
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity) // flex-1
    }
}

struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}
