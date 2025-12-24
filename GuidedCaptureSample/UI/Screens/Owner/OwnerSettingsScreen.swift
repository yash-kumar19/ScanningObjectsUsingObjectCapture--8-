import SwiftUI

struct OwnerSettingsScreen: View {
    var onLogout: () -> Void
    
    @State private var notificationsNewReservations = true
    @State private var notificationsOrderUpdates = true
    @State private var notificationsMarketing = false
    @State private var twoFactorEnabled = false
    
    let restaurantInfo = [
        (icon: "storefront.fill", label: "Restaurant Name", value: "The Golden Fork"),
        (icon: "envelope.fill", label: "Email", value: "contact@goldenfork.com"),
        (icon: "phone.fill", label: "Phone", value: "+1 (555) 123-4567"),
        (icon: "map.fill", label: "Address", value: "123 Main St, Downtown"),
        (icon: "globe", label: "Website", value: "www.goldenfork.com"),
        (icon: "clock.fill", label: "Hours", value: "11:00 AM - 10:00 PM"),
        (icon: "dollarsign.circle.fill", label: "Price Range", value: "$$$")
    ]
    
    let accountSettings = [
        (icon: "person.fill", label: "Owner Name", value: "John Doe"),
        (icon: "envelope.fill", label: "Account Email", value: "john@goldenfork.com"),
        (icon: "phone.fill", label: "Phone Number", value: "+1 (555) 987-6543")
    ]
    
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
            
            // 2. Background Glow Blob
            VStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "2b7fff").opacity(0.4), Color(hex: "2b7fff").opacity(0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 250
                        )
                    )
                    .frame(width: 380, height: 380)
                    .blur(radius: 100)
                    .offset(y: -250)
                Spacer()
            }
            .ignoresSafeArea()
            
            // 3. Content
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Settings")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.white)
                        Text("Manage your restaurant and account")
                            .font(.body)
                            .foregroundColor(Color.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 24)
                    
                    // Restaurant Information
                    SettingsSection(title: "Restaurant Information", icon: "storefront.fill") {
                        VStack(spacing: 0) {
                            ForEach(Array(restaurantInfo.enumerated()), id: \.offset) { index, item in
                                SettingsRow(icon: item.icon, label: item.label, value: item.value)
                                if index < restaurantInfo.count - 1 {
                                    Divider().background(Color.white.opacity(0.05)).padding(.leading, 48)
                                }
                            }
                        }
                    }
                    
                    // Owner Account
                    SettingsSection(title: "Owner Account", icon: "person.fill") {
                        VStack(spacing: 0) {
                            ForEach(Array(accountSettings.enumerated()), id: \.offset) { index, item in
                                SettingsRow(icon: item.icon, label: item.label, value: item.value)
                                if index < accountSettings.count - 1 {
                                    Divider().background(Color.white.opacity(0.05)).padding(.leading, 48)
                                }
                            }
                        }
                    }
                    
                    // Security
                    SettingsSection(title: "Security", icon: "lock.fill") {
                        Button(action: {}) {
                            HStack(spacing: 12) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(hex: "2b7fff"))
                                    .frame(width: 20)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Change Password")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                    Text("Last changed 3 months ago")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color.white.opacity(0.6))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.white.opacity(0.4))
                            }
                            .padding(16)
                        }
                    }
                    
                    // Two-Step Authentication
                    SettingsSection(title: "Two-Step Authentication", icon: "shield.fill") {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Enable 2FA")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                Text("Add an extra layer of security to your account")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.white.opacity(0.6))
                            }
                            Spacer()
                            CustomToggle(isOn: $twoFactorEnabled)
                        }
                        .padding(16)
                    }
                    
                    // Notification Settings
                    SettingsSection(title: "Notification Settings", icon: "bell.fill") {
                        VStack(spacing: 16) {
                            NotificationToggleRow(title: "New Reservations", isOn: $notificationsNewReservations)
                            NotificationToggleRow(title: "Order Updates", isOn: $notificationsOrderUpdates)
                            NotificationToggleRow(title: "Marketing", isOn: $notificationsMarketing)
                        }
                        .padding(16)
                    }
                    
                    // Logout Button
                    Button(action: onLogout) {
                        Text("Log Out")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "f87171"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(hex: "ef4444").opacity(0.1))
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color(hex: "ef4444").opacity(0.3), lineWidth: 1)
                            )
                    }
                    .padding(.bottom, 120)
                }
                .padding(.horizontal, 24) // Standard padding
                .frame(maxWidth: 500)
            }
        }
    }
}

// MARK: - Helper Components

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "2b7fff"))
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 0) {
                content
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: Color(hex: "2b7fff").opacity(0.15), radius: 32, x: 0, y: 8)
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        Button(action: {}) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "2b7fff"))
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.6))
                    Text(value)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(Color.white.opacity(0.4))
            }
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct NotificationToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.white)
            Spacer()
            CustomToggle(isOn: $isOn)
        }
    }
}

struct CustomToggle: View {
    @Binding var isOn: Bool
    
    var body: some View {
        Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isOn.toggle() } }) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? Color(hex: "2b7fff") : Color.white.opacity(0.1))
                    .frame(width: 48, height: 24)
                    .shadow(color: isOn ? Color(hex: "2b7fff").opacity(0.4) : .clear, radius: 10)
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                    .padding(.horizontal, 2)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
