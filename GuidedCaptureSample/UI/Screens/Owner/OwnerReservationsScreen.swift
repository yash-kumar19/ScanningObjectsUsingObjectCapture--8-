import SwiftUI

// MARK: - Models
struct OwnerReservation: Identifiable {
    let id: String
    let customerName: String
    let email: String
    let phone: String
    let date: String
    let time: String
    let guests: Int
    let status: OwnerReservationStatus
    let special: String?
}

enum OwnerReservationStatus: String {
    case confirmed
    case pending
    case cancelled
    
    var label: String {
        switch self {
        case .confirmed: return "Confirmed"
        case .pending: return "Pending"
        case .cancelled: return "Cancelled"
        }
    }
    
    var color: Color {
        switch self {
        case .confirmed: return Color(hex: "4ade80") // green-400
        case .pending: return Color(hex: "facc15") // yellow-400
        case .cancelled: return Color(hex: "f87171") // red-400
        }
    }
    
    var bgColor: Color {
        switch self {
        case .confirmed: return Color(hex: "22c55e").opacity(0.1) // green-500/10
        case .pending: return Color(hex: "eab308").opacity(0.1) // yellow-500/10
        case .cancelled: return Color(hex: "ef4444").opacity(0.1) // red-500/10
        }
    }
    
    var borderColor: Color {
        switch self {
        case .confirmed: return Color(hex: "22c55e").opacity(0.3) // green-500/30
        case .pending: return Color(hex: "eab308").opacity(0.3) // yellow-500/30
        case .cancelled: return Color(hex: "ef4444").opacity(0.3) // red-500/30
        }
    }
}

// MARK: - Screen
struct OwnerReservationsScreen: View {
    @State private var searchQuery = ""
    @State private var selectedDate = "today"
    
    let dateFilters = [
        (id: "today", label: "Today"),
        (id: "tomorrow", label: "Tomorrow"),
        (id: "week", label: "This Week"),
        (id: "all", label: "All")
    ]
    
    let reservations = [
        OwnerReservation(
            id: "1",
            customerName: "John Smith",
            email: "john.smith@email.com",
            phone: "+1 (555) 123-4567",
            date: "Today",
            time: "7:00 PM",
            guests: 4,
            status: .confirmed,
            special: "Window seat requested"
        ),
        OwnerReservation(
            id: "2",
            customerName: "Sarah Johnson",
            email: "sarah.j@email.com",
            phone: "+1 (555) 987-6543",
            date: "Today",
            time: "8:30 PM",
            guests: 2,
            status: .pending,
            special: "Anniversary celebration"
        ),
        OwnerReservation(
            id: "3",
            customerName: "Michael Brown",
            email: "mbrown@email.com",
            phone: "+1 (555) 456-7890",
            date: "Tomorrow",
            time: "6:00 PM",
            guests: 6,
            status: .confirmed,
            special: nil
        ),
        OwnerReservation(
            id: "4",
            customerName: "Emily Davis",
            email: "emily.d@email.com",
            phone: "+1 (555) 234-5678",
            date: "Dec 25",
            time: "7:30 PM",
            guests: 8,
            status: .cancelled,
            special: nil
        )
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
                VStack(spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reservations")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.white)
                        Text("Manage your table bookings")
                            .font(.body)
                            .foregroundColor(Color.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 24)
                    
                    // Search and Filter
                    HStack(spacing: 12) {
                        // Search Bar
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(Color.white.opacity(0.4))
                            
                            TextField("Search by name...", text: $searchQuery)
                                .foregroundColor(.white)
                                .accentColor(Color(hex: "2b7fff"))
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .shadow(color: Color(hex: "2b7fff").opacity(0.15), radius: 32, x: 0, y: 8)
                        
                        // Filter Button
                        Button(action: { /* Filter */ }) {
                            Image(systemName: "line.3.horizontal.decrease")
                                .font(.system(size: 20))
                                .foregroundColor(Color.white.opacity(0.6))
                                .frame(width: 56, height: 56)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        }
                    }
                    
                    // Date Filters
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(dateFilters, id: \.id) { filter in
                                Button(action: { selectedDate = filter.id }) {
                                    Text(filter.label)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(selectedDate == filter.id ? .white : Color.white.opacity(0.6))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            selectedDate == filter.id ? Color(hex: "2b7fff").opacity(0.2) : Color.white.opacity(0.05)
                                        )
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    selectedDate == filter.id ? Color(hex: "2b7fff") : Color.white.opacity(0.08),
                                                    lineWidth: 1
                                                )
                                        )
                                }
                            }
                        }
                    }
                    
                    // Reservations List
                    VStack(spacing: 16) {
                        ForEach(reservations) { reservation in
                            OwnerReservationCard(reservation: reservation)
                        }
                    }
                    
                    Spacer().frame(height: 120) // Bottom padding
                }
                .padding(.horizontal, 24) // Standard padding
                .frame(maxWidth: 500)
            }
        }
    }
}

struct OwnerReservationCard: View {
    let reservation: OwnerReservation
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(reservation.customerName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 8) {
                        Text(reservation.status.label)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(reservation.status.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(reservation.status.bgColor)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(reservation.status.borderColor, lineWidth: 1)
                            )
                        
                        Text(reservation.date)
                            .font(.system(size: 12))
                            .foregroundColor(Color.white.opacity(0.5))
                    }
                }
                Spacer()
            }
            
            // Contact Info
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "envelope")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "2b7fff"))
                    Text(reservation.email)
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.6))
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "phone")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "2b7fff"))
                    Text(reservation.phone)
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.6))
                }
            }
            
            // Reservation Details
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "2b7fff"))
                    Text(reservation.time)
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.7))
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "person.2")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "2b7fff"))
                    Text("\(reservation.guests) Guests")
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.7))
                }
                
                Spacer()
            }
            .padding(.bottom, 12)
            .overlay(
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1),
                alignment: .bottom
            )
            
            // Special Requests
            if let special = reservation.special {
                HStack(alignment: .top, spacing: 8) {
                    Text("💬")
                        .font(.system(size: 12))
                    Text(special)
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.6))
                    Spacer()
                }
                .padding(8)
                .background(Color.white.opacity(0.03))
                .cornerRadius(8)
            }
            
            // Actions
            if reservation.status == .pending {
                HStack(spacing: 12) {
                    Button(action: { /* Confirm */ }) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12))
                            Text("Confirm")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(Color(hex: "4ade80"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(hex: "22c55e").opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "22c55e").opacity(0.3), lineWidth: 1)
                        )
                    }
                    
                    Button(action: { /* Decline */ }) {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12))
                            Text("Decline")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(Color(hex: "f87171"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(hex: "ef4444").opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "ef4444").opacity(0.3), lineWidth: 1)
                        )
                    }
                }
            } else if reservation.status == .confirmed {
                Button(action: { /* Cancel */ }) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12))
                        Text("Cancel Reservation")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(Color(hex: "f87171"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(hex: "ef4444").opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "ef4444").opacity(0.3), lineWidth: 1)
                    )
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color(hex: "2b7fff").opacity(0.15), radius: 32, x: 0, y: 8)
    }
}
