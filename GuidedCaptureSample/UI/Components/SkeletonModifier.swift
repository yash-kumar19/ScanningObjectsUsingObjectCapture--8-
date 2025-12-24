import SwiftUI

struct SkeletonModifier: ViewModifier {
    var isLoading: Bool
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        if isLoading {
            content
                .opacity(0) // Hide original content
                .overlay(
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Color.white.opacity(0.1)
                            
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .white.opacity(0.1), location: 0.3),
                                    .init(color: .white.opacity(0.2), location: 0.5),
                                    .init(color: .white.opacity(0.1), location: 0.7),
                                    .init(color: .clear, location: 1)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: geo.size.width * 2) // Make gradient wider
                            .offset(x: -geo.size.width + (phase * 2 * geo.size.width))
                        }
                    }
                    .mask(content) // Mask with the shape of the content
                )
                .onAppear {
                    withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        phase = 1
                    }
                }
        } else {
            content
        }
    }
}

extension View {
    func skeleton(isLoading: Bool) -> some View {
        modifier(SkeletonModifier(isLoading: isLoading))
    }
}
