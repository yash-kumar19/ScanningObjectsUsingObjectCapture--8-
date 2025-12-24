import SwiftUI

struct CaptureSetupScreen: View {
    @Environment(\.dismiss) var dismiss
    var detailLevel: String = "medium"
    var onStartCapture: (() -> Void)? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "050505").ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 24) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "3b82f6").opacity(0.2))
                                .frame(width: 100, height: 100)
                                .blur(radius: 30)
                            
                            Image(systemName: "camera.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                                .frame(width: 80, height: 80)
                                .background(Color(hex: "3b82f6"))
                                .clipShape(Circle())
                                .shadow(color: Color(hex: "3b82f6").opacity(0.5), radius: 20, x: 0, y: 10)
                        }
                        .padding(.top, 40)
                        
                        VStack(spacing: 8) {
                            Text("Capture Setup")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Follow these guidelines for best results")
                                .font(.body)
                                .foregroundColor(Color.white.opacity(0.6))
                        }
                    }
                    
                    // Guidelines List
                    VStack(spacing: 16) {
                        GuidelineCard(
                            icon: "lightbulb.fill",
                            iconColor: Color(hex: "fbbf24"), // Amber
                            title: "Good Lighting",
                            description: "Use bright, even lighting without harsh shadows"
                        )
                        
                        GuidelineCard(
                            icon: "mappin.circle.fill",
                            iconColor: Color(hex: "ef4444"), // Red
                            title: "Center the Dish",
                            description: "Place the dish on a plain surface in the center"
                        )
                        
                        GuidelineCard(
                            icon: "arrow.triangle.2.circlepath",
                            iconColor: Color.white, // White for rotate
                            title: "Rotate Smoothly",
                            description: "Take photos every 10° while rotating around the dish"
                        )
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                    
                    // Start Button
                    Button(action: {
                        dismiss()
                        onStartCapture?()
                    }) {
                        Text("Start Capture")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color(hex: "3b82f6"))
                            .cornerRadius(20)
                            .shadow(color: Color(hex: "3b82f6").opacity(0.4), radius: 20, x: 0, y: 10)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
            }
        }
    }
}

struct GuidelineCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .frame(width: 56, height: 56)
            
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(iconColor)
        }
        
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Text(description)
                .font(.system(size: 14))
                .foregroundColor(Color.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
        
        Spacer()
    }
    .padding(20)
    .background(Color(hex: "111827"))
    .cornerRadius(24)
    .overlay(
        RoundedRectangle(cornerRadius: 24)
            .stroke(Color.white.opacity(0.1), lineWidth: 1)
    )
}
}
