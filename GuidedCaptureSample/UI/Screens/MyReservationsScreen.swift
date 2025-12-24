import SwiftUI

struct MyReservationsScreen: View {
    @State private var activeTab: ReservationTab = .upcoming
    
    enum ReservationTab {
        case upcoming, history
    }
    
    let upcomingReservations = [
        ReservationData(
            id: "1",
            restaurant: "The Golden Fork",
            cuisine: "Fine Dining",
            location: "Downtown Manhattan",
            image: "https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=400",
            date: "Dec 28, 2024",
            time: "7:30 PM",
            guests: 4,
            status: .confirmed
        ),
        ReservationData(
            id: "2",
            restaurant: "Sakura Sushi",
            cuisine: "Japanese",
            location: "Midtown",
            image: "https://images.unsplash.com/photo-1579584425555-c3ce17fd4351?w=400",
            date: "Dec 30, 2024",
            time: "6:00 PM",
            guests: 2,
            status: .pending
        ),
        ReservationData(
            id: "3",
            restaurant: "La Bella Vista",
            cuisine: "Italian",
            location: "Upper East Side",
            image: "https://images.unsplash.com/photo-1559339352-11d035aa65de?w=400",
            date: "Jan 5, 2025",
            time: "8:00 PM",
            guests: 6,
            status: .confirmed
        )
    ]
    
    let pastReservations = [
        PastReservationData(
            id: "4",
            restaurant: "Ocean Blue",
            cuisine: "Seafood",
            location: "Harbor District",
            image: "https://images.unsplash.com/photo-1559339352-11d035aa65de?w=400",
            date: "Nov 15, 2024",
            time: "7:00 PM",
            guests: 3,
            rating: 5
        ),
        PastReservationData(
            id: "5",
            restaurant: "The Spice Route",
            cuisine: "Indian",
            location: "Chelsea",
            image: "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=400",
            date: "Nov 8, 2024",
            time: "6:30 PM",
            guests: 2,
            rating: 4
        )
    ]
    
    var body: some View {
        ZStack {
            // Background
            Color.appBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    headerSection
                    
                    // Tab Switcher
                    tabSwitcher
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    
                    // Content
                    if activeTab == .upcoming {
                        upcomingSection
                    } else {
                        historySection
                    }
                    
                    // Bottom padding for tab bar
                    Color.clear.frame(height: 100)
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("My Reservations")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                // Active badge
                HStack(spacing: 4) {
                    Text("\(upcomingReservations.count) Active")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.fromHex("3B82F6"))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    LinearGradient(
                        colors: [
                            Color.fromHex("3B82F6").opacity(0.2),
                            Color.fromHex("3B82F6").opacity(0.2)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.fromHex("3B82F6").opacity(0.4), lineWidth: 1)
                )
                .shadow(color: Color.fromHex("3B82F6").opacity(0.2), radius: 12, x: 0, y: 4)
            }
            
            Text("View and manage your upcoming and past reservations")
                .font(.system(size: 15))
                .foregroundColor(Color.fromHex("94A3B8"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 24)
    }
    
    // MARK: - Tab Switcher
    private var tabSwitcher: some View {
        HStack(spacing: 8) {
            TabButton(
                title: "Upcoming",
                isSelected: activeTab == .upcoming,
                action: { activeTab = .upcoming }
            )
            
            TabButton(
                title: "History",
                isSelected: activeTab == .history,
                action: { activeTab = .history }
            )
        }
        .padding(6)
        .background(Color.fromHex("1E293B").opacity(0.6))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    // MARK: - Upcoming Section
    private var upcomingSection: some View {
        VStack(spacing: 16) {
            ForEach(upcomingReservations, id: \.id) { reservation in
                ReservationCard(reservation: reservation)
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - History Section
    private var historySection: some View {
        VStack(spacing: 16) {
            ForEach(pastReservations, id: \.id) { reservation in
                PastReservationCard(reservation: reservation)
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Tab Button
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(isSelected ? .white : Color.fromHex("94A3B8"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    Group {
                        if isSelected {
                            LinearGradient(
                                colors: [
                                    Color.fromHex("2B7FFF"),
                                    Color.fromHex("3B82F6")
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        } else {
                            Color.clear
                        }
                    }
                )
                .cornerRadius(12)
                .shadow(
                    color: isSelected ? Color.fromHex("3B82F6").opacity(0.3) : Color.clear,
                    radius: 16,
                    x: 0,
                    y: 4
                )
        }
    }
}

// MARK: - Reservation Card
struct ReservationCard: View {
    let reservation: ReservationData
    @State private var isPressed = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                // Restaurant Image
                AsyncImage(url: URL(string: reservation.image)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    default:
                        Rectangle()
                            .fill(Color.fromHex("1E293B"))
                            .frame(width: 80, height: 80)
                            .cornerRadius(16)
                    }
                }
                
                // Restaurant Info
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(reservation.restaurant)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Status Badge
                        Text(reservation.status.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(reservation.status.color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(reservation.status.color.opacity(0.2))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(reservation.status.color.opacity(0.4), lineWidth: 1)
                            )
                    }
                    
                    // Cuisine Badge
                    Text(reservation.cuisine)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                    
                    // Location
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.system(size: 12))
                            .foregroundColor(Color.fromHex("64748B"))
                        
                        Text(reservation.location)
                            .font(.system(size: 12))
                            .foregroundColor(Color.fromHex("64748B"))
                            .lineLimit(1)
                    }
                }
            }
            .padding(16)
            
            // Date, Time, Guests
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14))
                        .foregroundColor(Color.fromHex("3B82F6"))
                    Text(reservation.date)
                        .font(.system(size: 12))
                        .foregroundColor(Color.fromHex("94A3B8"))
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 14))
                        .foregroundColor(Color.fromHex("3B82F6"))
                    Text(reservation.time)
                        .font(.system(size: 12))
                        .foregroundColor(Color.fromHex("94A3B8"))
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "person.2")
                        .font(.system(size: 14))
                        .foregroundColor(Color.fromHex("3B82F6"))
                    Text("\(reservation.guests)")
                        .font(.system(size: 12))
                        .foregroundColor(Color.fromHex("94A3B8"))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            
            // Action Buttons
            HStack(spacing: 12) {
                Button(action: {}) {
                    HStack {
                        Image(systemName: "eye")
                            .font(.system(size: 14))
                        Text("View Details")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                
                Button(action: {}) {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.fromHex("EF4444"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.fromHex("EF4444").opacity(0.15))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.fromHex("EF4444").opacity(0.3), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(reservation.status.backgroundColor)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(reservation.status.borderColor, lineWidth: 1)
        )
        .shadow(color: reservation.status.shadowColor, radius: 20, x: 0, y: 8)
    }
}

// MARK: - Past Reservation Card
struct PastReservationCard: View {
    let reservation: PastReservationData
    
    var body: some View {
        HStack(spacing: 12) {
            // Restaurant Image
            AsyncImage(url: URL(string: reservation.image)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .opacity(0.8)
                default:
                    Rectangle()
                        .fill(Color.fromHex("1E293B"))
                        .frame(width: 80, height: 80)
                        .cornerRadius(16)
                }
            }
            
            // Restaurant Info
            VStack(alignment: .leading, spacing: 8) {
                Text(reservation.restaurant)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(reservation.cuisine)
                    .font(.system(size: 12))
                    .foregroundColor(Color.fromHex("94A3B8"))
                
                // Date & Guests
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12))
                            .foregroundColor(Color.fromHex("64748B"))
                        Text(reservation.date)
                            .font(.system(size: 11))
                            .foregroundColor(Color.fromHex("94A3B8"))
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "person.2")
                            .font(.system(size: 12))
                            .foregroundColor(Color.fromHex("64748B"))
                        Text("\(reservation.guests)")
                            .font(.system(size: 11))
                            .foregroundColor(Color.fromHex("94A3B8"))
                    }
                }
                
                // Rating & Review Button
                HStack {
                    HStack(spacing: 2) {
                        ForEach(0..<5) { index in
                            Image(systemName: index < reservation.rating ? "star.fill" : "star")
                                .font(.system(size: 14))
                                .foregroundColor(index < reservation.rating ? Color.fromHex("FCD34D") : Color.white.opacity(0.2))
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {}) {
                        Text("View Review")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.fromHex("8B5CF6"))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.fromHex("8B5CF6").opacity(0.2))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.fromHex("8B5CF6").opacity(0.4), lineWidth: 1)
                            )
                    }
                }
            }
        }
        .padding(16)
        .background(Color.fromHex("1E293B").opacity(0.6))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.fromHex("8B5CF6").opacity(0.1), radius: 20, x: 0, y: 8)
    }
}

// MARK: - Models
struct ReservationData {
    let id: String
    let restaurant: String
    let cuisine: String
    let location: String
    let image: String
    let date: String
    let time: String
    let guests: Int
    let status: ReservationStatus
}

struct PastReservationData {
    let id: String
    let restaurant: String
    let cuisine: String
    let location: String
    let image: String
    let date: String
    let time: String
    let guests: Int
    let rating: Int
}

enum ReservationStatus: String {
    case confirmed = "Confirmed"
    case pending = "Pending"
    case cancelled = "Cancelled"
    
    var color: Color {
        switch self {
        case .confirmed: return Color.fromHex("22C55E")
        case .pending: return Color.fromHex("EAB308")
        case .cancelled: return Color.fromHex("EF4444")
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .confirmed: return Color.fromHex("22C55E").opacity(0.05)
        case .pending: return Color.fromHex("EAB308").opacity(0.05)
        case .cancelled: return Color.fromHex("EF4444").opacity(0.05)
        }
    }
    
    var borderColor: Color {
        switch self {
        case .confirmed: return Color.fromHex("22C55E").opacity(0.2)
        case .pending: return Color.fromHex("EAB308").opacity(0.2)
        case .cancelled: return Color.fromHex("EF4444").opacity(0.2)
        }
    }
    
    var shadowColor: Color {
        switch self {
        case .confirmed: return Color.fromHex("22C55E").opacity(0.15)
        case .pending: return Color.fromHex("EAB308").opacity(0.15)
        case .cancelled: return Color.fromHex("EF4444").opacity(0.15)
        }
    }
}

#Preview {
    MyReservationsScreen()
}
