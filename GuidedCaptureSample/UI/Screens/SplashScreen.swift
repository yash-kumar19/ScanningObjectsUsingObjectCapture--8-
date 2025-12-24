import SwiftUI

struct SplashScreen: View {
    // Callbacks
    var onComplete: () -> Void
    
    // Animation States
    @State private var isIconScaled = false
    @State private var isIconRotated = false
    @State private var ring1Scale = 1.0
    @State private var ring1Opacity = 0.5
    @State private var ring2Scale = 1.0
    @State private var ring2Opacity = 0.3
    @State private var textOpacity = 0.0
    @State private var textOffset: CGFloat = 20
    @State private var subtitleOpacity = 0.0
    @State private var dot1Scale: CGFloat = 1.0
    @State private var dot1Opacity: Double = 0.3
    @State private var dot2Scale: CGFloat = 1.0
    @State private var dot2Opacity: Double = 0.3
    @State private var dot3Scale: CGFloat = 1.0
    @State private var dot3Opacity: Double = 0.3
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            GlowBackground()
            
            VStack(spacing: 24) {
                // Animated 3D Icon Container
                ZStack {
                    // Glow Rings
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Theme.primaryBlue, lineWidth: 2)
                        .frame(width: 128, height: 128)
                        .scaleEffect(ring1Scale)
                        .opacity(ring1Opacity)
                    
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Theme.primaryPurple, lineWidth: 2)
                        .frame(width: 128, height: 128)
                        .scaleEffect(ring2Scale)
                        .opacity(ring2Opacity)
                    
                    // Main Icon
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [Theme.primaryBlue, Theme.primaryPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 128, height: 128)
                        .shadow(color: Theme.primaryBlue.opacity(0.5), radius: 20, x: 0, y: 10)
                        .overlay(
                            Image(systemName: "fork.knife")
                                .font(.system(size: 64))
                                .foregroundColor(.white)
                        )
                        .scaleEffect(isIconScaled ? 1.0 : 0.0)
                        .rotationEffect(.degrees(isIconRotated ? 0 : -180))
                        // Continuous rotation animation simulated
                        .rotation3DEffect(
                            .degrees(isIconRotated ? 360 : 0),
                            axis: (x: 0, y: 1, z: 0)
                        )
                }
                .frame(width: 200, height: 200)
                
                // App Name & Subtitle
                VStack(spacing: 8) {
                    Text("HoloMenu")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Theme.primaryBlue, Theme.primaryPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .opacity(textOpacity)
                        .offset(y: textOffset)
                    
                    Text("Experience dining in 3D")
                        .font(.body)
                        .foregroundColor(Theme.textSecondary)
                        .opacity(subtitleOpacity)
                }
                
                // Loading Indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(Theme.primaryBlue)
                        .frame(width: 8, height: 8)
                        .scaleEffect(dot1Scale)
                        .opacity(dot1Opacity)
                    
                    Circle()
                        .fill(Theme.primaryBlue)
                        .frame(width: 8, height: 8)
                        .scaleEffect(dot2Scale)
                        .opacity(dot2Opacity)
                    
                    Circle()
                        .fill(Theme.primaryBlue)
                        .frame(width: 8, height: 8)
                        .scaleEffect(dot3Scale)
                        .opacity(dot3Opacity)
                }
                .padding(.top, 16)
                .opacity(textOpacity) // Show with text
            }
        }
        .onAppear {
            startAnimations()
            
            // Complete after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                onComplete()
            }
        }
    }
    
    private func startAnimations() {
        // 1. Icon Appearance
        withAnimation(.spring(response: 1, dampingFraction: 0.6)) {
            isIconScaled = true
            isIconRotated = true
        }
        
        // 2. Continuous Ring Animations
        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
            ring1Scale = 1.5
            ring1Opacity = 0.0
        }
        
        // Delay ring 2 slightly
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                ring2Scale = 1.8
                ring2Opacity = 0.0
            }
        }
        
        // 3. Text Appearance
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.8)) {
                textOpacity = 1.0
                textOffset = 0
            }
        }
        
        // 4. Subtitle Appearance
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.8)) {
                subtitleOpacity = 1.0
            }
        }
        
        // 5. Loading Dots Animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            animateDots()
        }
    }
    
    private func animateDots() {
        let duration = 1.0
        
        withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
            // Dot 1
            withAnimation(.easeInOut(duration: duration).repeatForever()) {
                dot1Scale = 1.5
                dot1Opacity = 1.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeInOut(duration: duration).repeatForever()) {
                dot2Scale = 1.5
                dot2Opacity = 1.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeInOut(duration: duration).repeatForever()) {
                dot3Scale = 1.5
                dot3Opacity = 1.0
            }
        }
    }
}
