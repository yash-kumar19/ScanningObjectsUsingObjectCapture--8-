import SwiftUI

struct BottomTabBar: View {
    @Binding var selectedTab: Int
    @Namespace private var animation
    @ObservedObject var cartManager = CartManager.shared
    
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
                icon: "cart",
                title: "Cart",
                index: 2,
                selectedTab: $selectedTab,
                animation: animation,
                badgeCount: cartManager.itemCount
            )
            
            TabBarItem(
                icon: "storefront.fill",
                title: "Partners",
                index: 3,
                selectedTab: $selectedTab,
                animation: animation
            )
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .fixedSize(horizontal: false, vertical: true) // Prevent vertical stretching
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

struct TabBarItem: View {
    let icon: String
    let title: String
    let index: Int
    @Binding var selectedTab: Int
    let animation: Namespace.ID
    var badgeCount: Int = 0  // Optional badge count for cart
    
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
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: icon)
                            .font(.system(size: 24))
                            .foregroundColor(selectedTab == index ? Color(hex: "2b7fff") : Color.white.opacity(0.6))
                        
                        // Badge for cart count
                        if badgeCount > 0 {
                            Text("\(badgeCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .frame(minWidth: 16, minHeight: 16)
                                .padding(.horizontal, 4)
                                .background(Color.red)
                                .clipShape(Circle())
                                .offset(x: 8, y: -8)
                        }
                    }
                    
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
