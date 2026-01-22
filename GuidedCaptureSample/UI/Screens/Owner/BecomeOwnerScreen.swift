import SwiftUI

struct BecomeOwnerScreen: View {
    var onContinue: () -> Void
    var onBack: () -> Void
    
    @State private var isHeaderVisible = false
    @State private var areBenefitsVisible = false
    @State private var isIllustrationVisible = false
    @State private var areButtonsVisible = false
    @State private var showOnboarding = false
    
    // Animation States for Emojis
    @State private var pizzaOffset: CGFloat = 0
    @State private var cameraOffset: CGFloat = 0
    @State private var sparklesOffset: CGFloat = 0
    
    let benefits = [
        BenefitItem(icon: "storefront.fill", title: "Create & Manage Dishes", description: "Upload and organize your restaurant's complete menu in 3D", color: Color(hex: "2b7fff")),
        BenefitItem(icon: "camera.fill", title: "3D Model Generation", description: "Use iPhone Object Capture to create stunning 3D dish models", color: Color(hex: "8b5cf6")),
        BenefitItem(icon: "chart.line.uptrend.xyaxis", title: "Attract More Customers", description: "Stand out with high-quality AR previews that boost engagement", color: Color(hex: "3b82f6")),
        BenefitItem(icon: "person.2.fill", title: "Manage Reservations", description: "Handle bookings and customer inquiries all in one place", color: Color(hex: "a78bfa"))
    ]
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            // Subtle glow
            // Glow removed per user request
            
            // 3. Content
            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 20)
                    
                    // Back Button
                    HStack {
                        Button(action: onBack) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.left")
                                Text("Back to Profile")
                            }
                            .foregroundColor(Color.white.opacity(0.6))
                        }
                        Spacer()
                    }
                    .padding(.bottom, 20)
                    
                    // Header
                    VStack(spacing: 24) {
                        // Icon
                        ZStack(alignment: .topTrailing) {
                            RoundedRectangle(cornerRadius: 28)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "2b7fff"), Color(hex: "8b5cf6")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 96, height: 96)
                                .shadow(color: Color(hex: "2b7fff").opacity(0.5), radius: 60, x: 0, y: 20)
                            
                            Image(systemName: "storefront.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.white)
                                .frame(width: 96, height: 96)
                            
                            // Sparkle Badge
                            Circle()
                                .fill(Color(hex: "8b5cf6"))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                )
                                .shadow(color: Color(hex: "8b5cf6").opacity(0.6), radius: 20, x: 0, y: 4)
                                .offset(x: 8, y: -8)
                        }
                        .scaleEffect(isHeaderVisible ? 1 : 0.8)
                        .opacity(isHeaderVisible ? 1 : 0)
                        
                        VStack(spacing: 12) {
                            Text("Switch to Restaurant Account")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            
                            Text("Unlock powerful tools to showcase your restaurant's dishes in stunning 3D and reach more customers")
                                .font(.body)
                                .foregroundColor(Color.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        .offset(y: isHeaderVisible ? 0 : 10)
                        .opacity(isHeaderVisible ? 1 : 0)
                    }
                    .padding(.bottom, 48)
                    
                    // Benefits Grid
                    VStack(spacing: 16) {
                        ForEach(0..<benefits.count, id: \.self) { index in
                            let benefit = benefits[index]
                            GlassCard(padding: 20) {
                                HStack(spacing: 16) {
                                    // Icon Box
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(
                                                LinearGradient(
                                                    colors: [benefit.color.opacity(0.2), benefit.color.opacity(0.1)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(benefit.color.opacity(0.3), lineWidth: 1)
                                            )
                                        
                                        Image(systemName: benefit.icon)
                                            .font(.system(size: 24))
                                            .foregroundColor(benefit.color)
                                    }
                                    .frame(width: 56, height: 56)
                                    .shadow(color: benefit.color.opacity(0.2), radius: 16, x: 0, y: 4)
                                    
                                    // Text
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(benefit.title)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                        
                                        Text(benefit.description)
                                            .font(.system(size: 14))
                                            .foregroundColor(Color.white.opacity(0.6))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer()
                                }
                            }
                            .offset(y: areBenefitsVisible ? 0 : 20)
                            .opacity(areBenefitsVisible ? 1 : 0)
                            .animation(.easeOut(duration: 0.5).delay(Double(index) * 0.1), value: areBenefitsVisible)
                        }
                    }
                    .padding(.bottom, 32)
                    
                    // Illustration Card
                    GlassCard(padding: 32) {
                        VStack(spacing: 24) {
                            HStack(spacing: 24) {
                                Text("🍕")
                                    .font(.system(size: 50))
                                    .offset(y: pizzaOffset)
                                Text("📸")
                                    .font(.system(size: 50))
                                    .offset(y: cameraOffset)
                                Text("✨")
                                    .font(.system(size: 50))
                                    .offset(y: sparklesOffset)
                            }
                            
                            Text("Transform your dishes into immersive 3D experiences and watch your restaurant thrive")
                                .font(.body)
                                .foregroundColor(Color.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .offset(y: isIllustrationVisible ? 0 : 20)
                    .opacity(isIllustrationVisible ? 1 : 0)
                    .padding(.bottom, 32)
                    
                    // CTA Buttons
                    VStack(spacing: 12) {
                        PrimaryButton(title: "Continue to Setup", fullWidth: true) {
                            showOnboarding = true
                        }
                        
                        SecondaryButton(title: "Maybe Later", fullWidth: true) {
                            onBack()
                        }
                    }
                    .offset(y: areButtonsVisible ? 0 : 20)
                    .opacity(areButtonsVisible ? 1 : 0)
                    
                    // Info Note
                    Text("You can switch back to customer mode anytime from settings")
                        .font(.caption)
                        .foregroundColor(Color.white.opacity(0.5))
                        .padding(.top, 24)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                        .opacity(areButtonsVisible ? 1 : 0)
                    
                    Spacer().frame(height: 40)
                }
                .frame(maxWidth: 500) // Max width constraint
                .padding(.horizontal, 24) // Standard padding
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            RestaurantOnboardingScreen(
                onComplete: {
                    showOnboarding = false
                    onContinue() // This will trigger the switch to Owner Dashboard in ProfileScreen
                },
                onBack: {
                    showOnboarding = false
                }
            )
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                isHeaderVisible = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                areBenefitsVisible = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.6)) {
                isIllustrationVisible = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.8)) {
                areButtonsVisible = true
            }
            
            startEmojiAnimation()
        }
    }
    
    private func startEmojiAnimation() {
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            pizzaOffset = -10
        }
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true).delay(0.3)) {
            cameraOffset = -10
        }
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true).delay(0.6)) {
            sparklesOffset = -10
        }
    }
}

struct BenefitItem {
    let icon: String
    let title: String
    let description: String
    let color: Color
}
