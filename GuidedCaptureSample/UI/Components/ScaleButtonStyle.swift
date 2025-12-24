import SwiftUI

struct ScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    var opacity: Double = 0.9
    var animationDuration: Double = 0.2
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .opacity(configuration.isPressed ? opacity : 1.0)
            .animation(.easeInOut(duration: animationDuration), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == ScaleButtonStyle {
    static var scale: ScaleButtonStyle {
        ScaleButtonStyle()
    }
    
    static func scale(amount: CGFloat = 0.96) -> ScaleButtonStyle {
        ScaleButtonStyle(scale: amount)
    }
}
