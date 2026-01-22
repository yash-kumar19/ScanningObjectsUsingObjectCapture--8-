import SwiftUI

struct GlassInput: View {
    let label: String
    @Binding var text: String
    var icon: String? = nil
    var placeholder: String = ""
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var isMultiline: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
            
            HStack(spacing: 12) {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundColor(Theme.textSecondary)
                }
                
                if isMultiline {
                    TextField(placeholder, text: $text, axis: .vertical)
                        .lineLimit(3...6)
                        .foregroundColor(.white)
                        .accentColor(Theme.primaryBlue)
                } else if isSecure {
                    SecureField(placeholder, text: $text)
                        .foregroundColor(.white)
                        .accentColor(Theme.primaryBlue)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .foregroundColor(.white)
                        .accentColor(Theme.primaryBlue)
                }
            }
            .padding(16)
            .background(
                Color(hex: "1e293b"), // Dark non-glass background
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
}
