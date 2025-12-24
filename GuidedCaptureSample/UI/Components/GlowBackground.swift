import SwiftUI

struct GlowBackground: View {
    var body: some View {
        ZStack {
            // Base gradient background
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
            
            // Blue radial glow - top right
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.primaryBlue.opacity(0.4), Theme.primaryBlue.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 250
                    )
                )
                .frame(width: 500, height: 500)
                .blur(radius: 120)
                .offset(x: 160, y: -160) // -top-40 -right-40 roughly
            
            // Purple radial glow - top left
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.primaryPurple.opacity(0.4), Theme.primaryPurple.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 250
                    )
                )
                .frame(width: 500, height: 500)
                .blur(radius: 120)
                .offset(x: -160, y: -160) // -top-40 -left-40 roughly
                .opacity(0.25)
            
            // Blue radial glow - bottom center
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.primaryBlue.opacity(0.3), Theme.primaryBlue.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 300
                    )
                )
                .frame(width: 600, height: 600)
                .blur(radius: 140)
                .offset(y: 400) // -bottom-40 (relative to bottom)
                .opacity(0.2)
            
            // Purple radial glow - middle right
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.primaryPurple.opacity(0.3), Theme.primaryPurple.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .blur(radius: 100)
                .offset(x: 128) // -right-32
                .opacity(0.2)
        }
    }
}
