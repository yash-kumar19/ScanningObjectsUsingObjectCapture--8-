import SwiftUI

enum UserRole: String {
    case owner
    case customer
}

struct RoleSelectionScreen: View {
    // Callbacks
    var onRoleSelect: (UserRole) -> Void
    var onLogin: () -> Void
    
    // State
    @State private var selectedRole: UserRole? = nil
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            // Background Glows
            ZStack {
                Circle()
                    .fill(Theme.primaryBlue.opacity(0.4))
                    .frame(width: 600, height: 600)
                    .blur(radius: 120)
                    .offset(y: -300)
                
                Circle()
                    .fill(Theme.primaryPurple.opacity(0.3))
                    .frame(width: 400, height: 400)
                    .blur(radius: 100)
                    .offset(x: 100, y: 300)
            }
            
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 60)
                
                // Header
                VStack(spacing: 12) {
                    Text("Welcome to 3D Menu App")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("Choose how you want to continue")
                        .font(.body)
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(.bottom, 48)
                
                // Role Selection Cards
                VStack(spacing: 16) {
                    // Owner Card
                    RoleCard(
                        role: .owner,
                        title: "Restaurant Owner",
                        description: "Manage your menu, reservations & analytics",
                        icon: "storefront.fill",
                        accentColor: Theme.primaryBlue,
                        isSelected: selectedRole == .owner,
                        action: { selectedRole = .owner }
                    )
                    
                    // Customer Card
                    RoleCard(
                        role: .customer,
                        title: "Customer",
                        description: "Browse menus & make reservations",
                        icon: "fork.knife",
                        accentColor: Color.green,
                        isSelected: selectedRole == .customer,
                        action: { selectedRole = .customer }
                    )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                
                // Continue Button
                Button(action: {
                    if let role = selectedRole {
                        onRoleSelect(role)
                    }
                }) {
                    HStack(spacing: 8) {
                        Text("Continue")
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        selectedRole != nil ? Theme.gradientBlue : LinearGradient(colors: [Color.white.opacity(0.05)], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(20)
                    .shadow(color: selectedRole != nil ? Theme.primaryBlue.opacity(0.4) : .clear, radius: 16, x: 0, y: 8)
                }
                .disabled(selectedRole == nil)
                .opacity(selectedRole != nil ? 1.0 : 0.5)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                
                // Login Link
                Button(action: onLogin) {
                    Text("Already have an account? ")
                        .foregroundColor(Theme.textSecondary) +
                    Text("Login")
                        .fontWeight(.bold)
                        .foregroundColor(Theme.primaryBlue)
                }
                .padding(.bottom, 40)
            }
        }
    }
}

struct RoleCard: View {
    let role: UserRole
    let title: String
    let description: String
    let icon: String
    let accentColor: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            GlassCard(padding: 0) {
                HStack(spacing: 16) {
                    // Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [accentColor, accentColor.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 64, height: 64)
                            .shadow(color: accentColor.opacity(0.3), radius: 16, x: 0, y: 8)
                        
                        Image(systemName: icon)
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    
                    // Content
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(description)
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                    // Selection Indicator
                    if isSelected {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 8, height: 8)
                            )
                            .shadow(color: accentColor.opacity(0.5), radius: 8, x: 0, y: 0)
                    }
                }
                .padding(24)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(isSelected ? accentColor : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
