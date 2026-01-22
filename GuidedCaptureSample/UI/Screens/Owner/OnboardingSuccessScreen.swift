import SwiftUI

struct OnboardingSuccessScreen: View {
    var onContinue: () -> Void
    
    @State private var isIconVisible = false
    @State private var isMessageVisible = false
    @State private var isCardVisible = false
    @State private var isNextStepsVisible = false
    @State private var isButtonVisible = false
    
    // Animation States
    @State private var sparkleRotation: Double = 0
    @State private var sparkleScale: CGFloat = 1.0
    
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
            
            // 2. Celebration Background Glow
            // Celebration glow removed per user request
            
            // 3. Confetti Effect (Simple Implementation)
            ConfettiView()
            
            // 4. Content
            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 60)
                    
                    // Success Icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "4ade80"), Color(hex: "16a34a")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 128, height: 128)
                            .shadow(color: Color(hex: "22c55e").opacity(0.5), radius: 40, x: 0, y: 30)
                        
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 64))
                            .foregroundColor(.white)
                        
                        // Sparkles
                        ZStack {
                            Image(systemName: "sparkles")
                                .font(.system(size: 32))
                                .foregroundColor(Color(hex: "facc15")) // Yellow
                                .offset(x: 50, y: -50)
                            
                            Image(systemName: "sparkles")
                                .font(.system(size: 24))
                                .foregroundColor(Color(hex: "c084fc")) // Purple
                                .offset(x: -50, y: 50)
                            
                            Image(systemName: "sparkle")
                                .font(.system(size: 20))
                                .foregroundColor(Color(hex: "60a5fa")) // Blue
                                .offset(x: -60, y: -20)
                            
                            Image(systemName: "sparkle")
                                .font(.system(size: 28))
                                .foregroundColor(Color(hex: "f472b6")) // Pink
                                .offset(x: 60, y: 20)
                        }
                        .rotationEffect(.degrees(sparkleRotation))
                        .scaleEffect(sparkleScale)
                    }
                    .scaleEffect(isIconVisible ? 1 : 0)
                    .opacity(isIconVisible ? 1 : 0)
                    .padding(.bottom, 48)
                    
                    // Success Message
                    VStack(spacing: 16) {
                        Text("Setup Complete! 🎉")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Your restaurant account is ready. Start uploading stunning 3D dishes to attract more customers.")
                            .font(.body)
                            .foregroundColor(Color.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .offset(y: isMessageVisible ? 0 : 20)
                    .opacity(isMessageVisible ? 1 : 0)
                    .padding(.bottom, 32)
                    
                    // Success Details Card
                    GlassCard(padding: 24) {
                        VStack(spacing: 20) {
                            SuccessItem(icon: "checkmark.circle.fill", color: Color(hex: "4ade80"), title: "Restaurant Profile Created", description: "Your restaurant is now visible to customers", delay: 0.1)
                            SuccessItem(icon: "checkmark.circle.fill", color: Color(hex: "60a5fa"), title: "3D Tools Unlocked", description: "Start creating immersive dish models", delay: 0.2)
                            SuccessItem(icon: "checkmark.circle.fill", color: Color(hex: "c084fc"), title: "Dashboard Access Granted", description: "Manage your menu and reservations", delay: 0.3)
                        }
                    }
                    .offset(y: isCardVisible ? 0 : 20)
                    .opacity(isCardVisible ? 1 : 0)
                    .padding(.bottom, 32)
                    
                    // Next Steps
                    VStack(spacing: 16) {
                        Text("What's Next?")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        VStack(spacing: 12) {
                            NextStepItem(text: "📸 Use your iPhone to capture 3D dish models", delay: 0.4)
                            NextStepItem(text: "🍽️ Upload your complete menu", delay: 0.5)
                            NextStepItem(text: "📊 Track customer engagement", delay: 0.6)
                            NextStepItem(text: "🔔 Manage reservations in real-time", delay: 0.7)
                        }
                    }
                    .offset(y: isNextStepsVisible ? 0 : 20)
                    .opacity(isNextStepsVisible ? 1 : 0)
                    .padding(.bottom, 40)
                    
                    // CTA Button
                    PrimaryButton(title: "Go to Restaurant Dashboard", fullWidth: true) {
                        onContinue()
                    }
                    .offset(y: isButtonVisible ? 0 : 20)
                    .opacity(isButtonVisible ? 1 : 0)
                    
                    Spacer().frame(height: 40)
                }
                .frame(maxWidth: 500) // Max width constraint
                .padding(.horizontal, 24) // Standard padding
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                isIconVisible = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                isMessageVisible = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.4)) {
                isCardVisible = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.6)) {
                isNextStepsVisible = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.8)) {
                isButtonVisible = true
            }
            
            // Sparkle Animation
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                sparkleRotation = 360
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                sparkleScale = 1.2
            }
        }
    }
}

// MARK: - Helper Components

struct SuccessItem: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    let delay: Double
    
    @State private var isVisible = false
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(Color.white.opacity(0.6))
            }
            Spacer()
        }
        .offset(x: isVisible ? 0 : -20)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(delay + 0.4)) { // Add base delay
                isVisible = true
            }
        }
    }
}

struct NextStepItem: View {
    let text: String
    let delay: Double
    
    @State private var isVisible = false
    
    var body: some View {
        HStack {
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(Color.white.opacity(0.9))
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(12)
        .offset(x: isVisible ? 0 : -20)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(delay + 0.6)) { // Add base delay
                isVisible = true
            }
        }
    }
}

struct ConfettiView: View {
    @State private var confetti: [ConfettiParticle] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(confetti) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .position(particle.position)
                        .opacity(particle.opacity)
                }
            }
            .onAppear {
                createConfetti(in: geometry.size)
            }
        }
        .allowsHitTesting(false)
    }
    
    private func createConfetti(in size: CGSize) {
        for _ in 0..<50 {
            let particle = ConfettiParticle(
                id: UUID(),
                position: CGPoint(x: CGFloat.random(in: 0...size.width), y: -10),
                color: [Color.red, Color.blue, Color.green, Color.yellow, Color.purple, Color.orange].randomElement()!,
                size: CGFloat.random(in: 4...8),
                opacity: 1.0
            )
            confetti.append(particle)
        }
        
        // Animate confetti
        for i in 0..<confetti.count {
            withAnimation(.easeOut(duration: Double.random(in: 2...4)).delay(Double.random(in: 0...0.5))) {
                confetti[i].position.y = size.height + 20
                confetti[i].position.x += CGFloat.random(in: -50...50)
                confetti[i].opacity = 0
            }
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id: UUID
    var position: CGPoint
    let color: Color
    let size: CGFloat
    var opacity: Double
}
