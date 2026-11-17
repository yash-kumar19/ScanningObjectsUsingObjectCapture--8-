import SwiftUI

struct PremiumDownloadView: View {
    let progress: Double
    let onCancel: () -> Void
    
    @State private var isAnimating = false
    @State private var pulseScale: CGFloat = 1.0
    
    private var progressPercent: Int { Int(progress * 100) }
    
    private var statusText: String {
        if progress < 0.3 {
            return "Initializing model assets..."
        } else if progress < 0.6 {
            return "Downloading textures & geometry..."
        } else if progress < 0.9 {
            return "Assembling 3D scene..."
        } else {
            return "Almost there..."
        }
    }
    
    var body: some View {
        ZStack {
            // Clean dark background
            Color(hex: "030712").ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Centered Spinner & 3D Cube
                ZStack {
                    // Outer background ring track
                    Circle()
                        .stroke(Color.white.opacity(0.06), lineWidth: 5)
                        .frame(width: 150, height: 150)
                    
                    // Progress arc spinner
                    Circle()
                        .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "3b82f6"), Color(hex: "8b5cf6")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .frame(width: 150, height: 150)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                    
                    // Glowing dot at progress tip
                    Circle()
                        .fill(Color(hex: "60a5fa"))
                        .frame(width: 10, height: 10)
                        .shadow(color: Color(hex: "3b82f6"), radius: 6)
                        .offset(y: -75) // Radius is 75
                        .rotationEffect(.degrees(360 * progress - 90))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                    
                    // 3D Cube Icon
                    Image(systemName: "cube.fill")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "60a5fa"), Color(hex: "a78bfa")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .rotation3DEffect(
                            .degrees(isAnimating ? 15 : -15),
                            axis: (x: 0.3, y: 1.0, z: 0.1)
                        )
                        .scaleEffect(pulseScale)
                        .shadow(color: Color(hex: "3b82f6").opacity(0.3), radius: 15, x: 0, y: 6)
                }
                .frame(width: 150, height: 150)
                
                // Status Info
                VStack(spacing: 12) {
                    Text("\(progressPercent)%")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: progressPercent)
                    
                    Text(statusText)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .frame(height: 24)
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: 0.3), value: statusText)
                }
                .padding(.horizontal, 40)
                
                // Cancel Button
                cancelButton
                
                Spacer()
            }
        }
        .onAppear {
            isAnimating = true
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulseScale = 1.15
            }
        }
    }
    
    private var cancelButton: some View {
        Button(action: onCancel) {
            HStack(spacing: 8) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                Text("Cancel")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(Color.white.opacity(0.6))
            .frame(width: 160, height: 48)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleEffectButtonStyle())
    }
}

struct ScaleEffectButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

