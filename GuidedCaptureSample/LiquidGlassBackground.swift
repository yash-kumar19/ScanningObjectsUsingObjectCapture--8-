import SwiftUI

struct LiquidGlassBackground: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            // Base background
            Color.appBackground.ignoresSafeArea()
            
            // Animated overlay blobs
            GeometryReader { proxy in
                ZStack {
                    // Blob 1: Blue/Purple
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hex: "3B82F6").opacity(0.4),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 300
                            )
                        )
                        .frame(width: 600, height: 600)
                        .scaleEffect(animate ? 1.2 : 1.0)
                        .offset(x: animate ? -100 : 100, y: animate ? -200 : 0)
                        .blur(radius: 60)
                    
                    // Blob 2: Cyan/Teal
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hex: "06B6D4").opacity(0.3),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 300
                            )
                        )
                        .frame(width: 500, height: 500)
                        .scaleEffect(animate ? 1.0 : 1.3)
                        .offset(x: animate ? 200 : -50, y: animate ? 300 : 100)
                        .blur(radius: 60)
                    
                    // Blob 3: Purple/Pink (Bottom)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hex: "8B5CF6").opacity(0.3),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 350
                            )
                        )
                        .frame(width: 700, height: 700)
                        .offset(x: animate ? -150 : 150, y: animate ? 400 : 500)
                        .blur(radius: 80)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color.black.opacity(0.3)) // Darken slightly for readability
            .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 7.0)
                .repeatForever(autoreverses: true)
            ) {
                animate.toggle()
            }
        }
    }
}

#Preview {
    LiquidGlassBackground()
}
