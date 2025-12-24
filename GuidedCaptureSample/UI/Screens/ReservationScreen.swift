import SwiftUI

struct ReservationScreen: View {
    // Callbacks
    var onBack: () -> Void
    
    // State
    @State private var date: Date = Date()
    @State private var time: Date = Date()
    @State private var guests: String = "2"
    @State private var specialRequest: String = ""
    @State private var showConfirmation: Bool = false
    
    // Helper for date formatting in confirmation
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }
    
    var body: some View {
        ZStack {
            GlowBackground()
            
            if showConfirmation {
                ConfirmationView(
                    date: formattedDate,
                    time: formattedTime,
                    guests: guests,
                    onDismiss: onBack
                )
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        HStack(spacing: 16) {
                            Button(action: onBack) {
                                Image(systemName: "arrow.left")
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(Color.white.opacity(0.05))
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            }
                            
                            Text("Make a Reservation")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        
                        // Restaurant Info
                        GlassCard {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("The Golden Fork")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("Fine Dining • Downtown")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 24)
                        
                        // Form
                        GlassCard {
                            VStack(spacing: 20) {
                                // Custom Date Picker styling using GlassInput look
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Date")
                                        .font(.subheadline)
                                        .foregroundColor(Theme.textSecondary)
                                    
                                    HStack {
                                        Image(systemName: "calendar")
                                            .foregroundColor(Theme.textSecondary)
                                        DatePicker("", selection: $date, displayedComponents: .date)
                                            .labelsHidden()
                                            .colorScheme(.dark)
                                            .accentColor(Theme.primaryBlue)
                                        Spacer()
                                    }
                                    .padding(16)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Time")
                                        .font(.subheadline)
                                        .foregroundColor(Theme.textSecondary)
                                    
                                    HStack {
                                        Image(systemName: "clock")
                                            .foregroundColor(Theme.textSecondary)
                                        DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                                            .labelsHidden()
                                            .colorScheme(.dark)
                                            .accentColor(Theme.primaryBlue)
                                        Spacer()
                                    }
                                    .padding(16)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                                }
                                
                                GlassInput(
                                    label: "Number of Guests",
                                    text: $guests,
                                    icon: "person.2",
                                    keyboardType: .numberPad
                                )
                                
                                GlassInput(
                                    label: "Special Requests",
                                    text: $specialRequest,
                                    icon: "message",
                                    placeholder: "Any allergies or special occasions?",
                                    isMultiline: true
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        // Time Slots
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Available Time Slots")
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                                .padding(.horizontal, 24)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(["6:00 PM", "7:00 PM", "8:00 PM", "9:00 PM"], id: \.self) { slot in
                                        Button(action: {
                                            // Parse string to date if needed, for now just visual
                                        }) {
                                            Text(slot)
                                                .font(.subheadline)
                                                .foregroundColor(Theme.textSecondary)
                                                .padding(.horizontal, 20)
                                                .padding(.vertical, 12)
                                                .background(Color.white.opacity(0.05))
                                                .cornerRadius(16)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 16)
                                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                                )
                                        }
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                        
                        // Info
                        GlassCard {
                            Text("💡 Your table will be held for 15 minutes after your reservation time. Please contact us if you'll be running late.")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 24)
                        
                        // Confirm Button
                        PrimaryButton(title: "Confirm Reservation", fullWidth: true) {
                            withAnimation {
                                showConfirmation = true
                            }
                            // Auto dismiss after 3 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                onBack()
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                }
                .transition(.opacity)
            }
        }
    }
}

struct ConfirmationView: View {
    let date: String
    let time: String
    let guests: String
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            
            GlassCard {
                VStack(spacing: 24) {
                    Circle()
                        .fill(LinearGradient(colors: [Color.green, Color.green.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                        .shadow(color: Color.green.opacity(0.5), radius: 20)
                    
                    VStack(spacing: 8) {
                        Text("Reservation Confirmed!")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Your table has been reserved. We've sent a confirmation to your email.")
                            .font(.body)
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    VStack(spacing: 12) {
                        HStack {
                            Text("Date")
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            Text(date)
                                .foregroundColor(.white)
                        }
                        Divider().background(Color.white.opacity(0.1))
                        HStack {
                            Text("Time")
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            Text(time)
                                .foregroundColor(.white)
                        }
                        Divider().background(Color.white.opacity(0.1))
                        HStack {
                            Text("Guests")
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            Text("\(guests) people")
                                .foregroundColor(.white)
                        }
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                }
                .padding(16)
            }
            .padding(24)
        }
    }
}
