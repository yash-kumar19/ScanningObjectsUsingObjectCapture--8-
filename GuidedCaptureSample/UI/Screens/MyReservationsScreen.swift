import SwiftUI

struct MyReservationsScreen: View {
    @State private var activeTab: ReservationTab = .upcoming
    @State private var reservations: [Reservation] = []
    @State private var isLoading = false
    
    @ObservedObject private var supabase = SupabaseManager.shared
    
    enum ReservationTab {
        case upcoming, history
    }
    
    var upcomingReservations: [Reservation] {
        reservations.filter {
            // Simple filter: if status is not cancelled and date is future (mock logic for now, or use complex date comparison)
            // For MVP, lets just say 'pending' or 'confirmed' are active/upcoming.
            // Or better, compare dates.
            guard let date = ISO8601DateFormatter().date(from: $0.reservation_date) else { return false }
            return date > Date() && $0.status != "cancelled"
        }
    }
    
    var pastReservations: [Reservation] {
        reservations.filter {
            guard let date = ISO8601DateFormatter().date(from: $0.reservation_date) else { return true }
            return date <= Date() || $0.status == "cancelled"
        }
    }
    
    var body: some View {
        ZStack {
            // Background
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    headerSection
                    
                    // Tab Switcher
                    tabSwitcher
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    
                    if isLoading {
                        ProgressView().tint(.white).padding(40)
                    } else if reservations.isEmpty {
                         Text("No reservations found.")
                            .foregroundColor(.gray)
                            .padding(40)
                    } else {
                        // Content
                        if activeTab == .upcoming {
                            if upcomingReservations.isEmpty {
                                Text("No upcoming reservations.")
                                    .foregroundColor(.gray)
                                    .padding(40)
                            } else {
                                upcomingSection
                            }
                        } else {
                            if pastReservations.isEmpty {
                                Text("No past reservations.")
                                    .foregroundColor(.gray)
                                    .padding(40)
                            } else {
                                historySection
                            }
                        }
                    }
                    
                    // Bottom padding for tab bar
                    Color.clear.frame(height: 100)
                }
            }
        }
        .onAppear {
            loadData()
            supabase.startPolling()
        }
        .onDisappear {
            supabase.stopPolling()
        }
        .onReceive(NotificationCenter.default.publisher(for: .supabaseDataDidUpdate)) { _ in
            loadData()
        }
    }
    
    private func loadData() {
        if reservations.isEmpty { isLoading = true }
        Task {
            do {
                let items = try await supabase.fetchMyReservations()
                await MainActor.run {
                    self.reservations = items
                    self.isLoading = false
                }
            } catch {
                print("Error fetching reservations: \(error)")
                await MainActor.run { self.isLoading = false }
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
            ForEach(upcomingReservations) { reservation in
                ReservationCard(reservation: reservation)
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - History Section
    private var historySection: some View {
        VStack(spacing: 16) {
            ForEach(pastReservations) { reservation in
                // Reusing ReservationCard for history for now, slightly different look if needed
                 ReservationCard(reservation: reservation, isPast: true)
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
    let reservation: Reservation
    var isPast: Bool = false
    @State private var isPressed = false
    
    var restaurantName: String {
        reservation.owner?.restaurant_name ?? "Restaurant"
    }
    
    var imageURL: URL? {
        if let urlStr = reservation.owner?.avatar_url, !urlStr.isEmpty {
            return URL(string: urlStr)
        }
        return URL(string: "https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=400")
    }
    
    var statusEnum: ReservationStatus {
        switch reservation.status {
            case "confirmed": return .confirmed
            case "cancelled": return .cancelled
            default: return .pending
        }
    }
    
    var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: reservation.reservation_date) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            return displayFormatter.string(from: date)
        }
        return reservation.reservation_date
    }
    
    var formattedTime: String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: reservation.reservation_date) {
            let displayFormatter = DateFormatter()
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return ""
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                // Restaurant Image
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                             .opacity(isPast ? 0.7 : 1)
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
                        Text(restaurantName)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Status Badge
                        if !isPast {
                            Text(statusEnum.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(statusEnum.color)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(statusEnum.color.opacity(0.2))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(statusEnum.color.opacity(0.4), lineWidth: 1)
                                )
                        } else {
                            // Simple text for past
                             Text(statusEnum.rawValue)
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // Cuisine Badge (Mocked or hidden if not available)
                     Text("Fine Dining") // Placeholder
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.7))
                        .hidden() // Hiding for now since we don't have it
                    
                    // Location
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.system(size: 12))
                            .foregroundColor(Color.fromHex("64748B"))
                        
                        Text("View Location") // Placeholder
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
                    Text(formattedDate)
                        .font(.system(size: 12))
                        .foregroundColor(Color.fromHex("94A3B8"))
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 14))
                        .foregroundColor(Color.fromHex("3B82F6"))
                    Text(formattedTime)
                        .font(.system(size: 12))
                        .foregroundColor(Color.fromHex("94A3B8"))
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "person.2")
                        .font(.system(size: 14))
                        .foregroundColor(Color.fromHex("3B82F6"))
                    Text("\(reservation.guest_count)")
                        .font(.system(size: 12))
                        .foregroundColor(Color.fromHex("94A3B8"))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            
            // Action Buttons
            if !isPast {
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
                    
                    if statusEnum != .cancelled {
                         Button(action: {
                             // Cancel Action... would need async func
                         }) {
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
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(statusEnum.backgroundColor)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(statusEnum.borderColor, lineWidth: 1)
        )
        .shadow(color: statusEnum.shadowColor, radius: 20, x: 0, y: 8)
    }
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
