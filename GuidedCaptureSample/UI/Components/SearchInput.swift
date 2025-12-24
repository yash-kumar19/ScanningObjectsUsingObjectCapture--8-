import SwiftUI

struct SearchInput: View {
    @Binding var text: String
    var placeholder: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(isFocused ? Theme.primaryBlue : Color.white.opacity(0.5))
            
            TextField(placeholder, text: $text)
                .foregroundColor(.white)
                .font(.subheadline)
                .accentColor(Theme.primaryBlue)
                .focused($isFocused)
                .placeholder(when: text.isEmpty) {
                    Text(placeholder)
                        .foregroundColor(Color.white.opacity(0.5))
                        .font(.subheadline)
                }
        }
        .padding(.horizontal, 12)  // px-3 from React
        .frame(height: 36)  // h-9 from React
        .background(Color.white.opacity(0.05))  // bg-input-background
        .cornerRadius(8)  // rounded-md
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isFocused ? Theme.primaryBlue : Color.white.opacity(0.1),
                    lineWidth: isFocused ? 2 : 1  // Focus border thicker
                )
        )
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}


