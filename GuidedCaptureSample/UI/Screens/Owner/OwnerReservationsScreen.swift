import SwiftUI

// MARK: - Screen
struct OwnerReservationsScreen: View {
    @State private var searchQuery = ""
    @State private var selectedDate = "all"
    @State private var reservations: [Reservation] = []
    @State private var isLoading = false
    
    @ObservedObject private var supabase = SupabaseManager.shared
    
    let dateFilters = [
        (id: "today", label: "Today"),
        (id: "tomorrow", label: "Tomorrow"),
        (id: "week", label: "This Week"),
        (id: "all", label: "All")
    ]
    
    var filteredReservations: [Reservation] {
        var result = reservations
        
        // Date Filter (Simplified logic for MVP)
        let calendar = Calendar.current
        let today = Date()
        
        if selectedDate == "today" {
            result = result.filter {
                guard let date = ISO8601DateFormatter().date(from: $0.reservation_date) else { return false }
                return calendar.isDateInToday(date)
            }
        } else if selectedDate == "tomorrow" {
            result = result.filter {
                guard let date = ISO8601DateFormatter().date(from: $0.reservation_date) else { return false }
                return calendar.isDateInTomorrow(date)
            }
        }
        // "week" logic omitted for brevity, keeping simple
        
        // Search Filter
        if !searchQuery.isEmpty {
            result = result.filter {
                let name = $0.customer?.full_name ?? ""
                return name.localizedCaseInsensitiveContains(searchQuery)
            }
        }
        
        return result
    }
    
    var body: some View {
        ZStack {
            // 1. Unified Liquid Glass Background
            Theme.background.ignoresSafeArea()
            
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
                    
                    if isLoading {
                        ProgressView().tint(.white).padding(40)
                    } else if filteredReservations.isEmpty {
                        Text("No reservations found.")
                            .foregroundColor(.gray)
                            .padding(40)
                    } else {
                        // Reservations List
                        VStack(spacing: 16) {
                            ForEach(filteredReservations) { reservation in
                                OwnerReservationCard(
                                    reservation: reservation,
                                    onConfirm: { updateStatus(id: reservation.id, status: "confirmed") },
                                    onDecline: { updateStatus(id: reservation.id, status: "cancelled") },
                                    onCancel: { updateStatus(id: reservation.id, status: "cancelled") }
                                )
                            }
                        }
                    }
                    
                    Spacer().frame(height: 120) // Bottom padding
                }
                .padding(.horizontal, 24) // Standard padding
                .frame(maxWidth: 500)
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
                let items = try await supabase.fetchOwnerReservations()
                await MainActor.run {
                    self.reservations = items
                    self.isLoading = false
                }
            } catch {
                print("Error fetching owner reservations: \(error)")
                await MainActor.run { self.isLoading = false }
            }
        }
    }
    
    private func updateStatus(id: String, status: String) {
        Task {
            try? await supabase.updateReservationStatus(id: id, status: status)
            loadData()
        }
    }
}

struct OwnerReservationCard: View {
    let reservation: Reservation
    var onConfirm: () -> Void
    var onDecline: () -> Void
    var onCancel: () -> Void
    
    var customerName: String {
        reservation.customer?.full_name ?? "Unknown"
    }
    
    var customerEmail: String {
        reservation.customer?.email ?? "No email"
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
    
    var statusEnum: OwnerReservationStatus {
        switch reservation.status {
            case "confirmed": return .confirmed
            case "cancelled": return .cancelled
            default: return .pending
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(customerName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 8) {
                        Text(statusEnum.label)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(statusEnum.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(statusEnum.bgColor)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(statusEnum.borderColor, lineWidth: 1)
                            )
                        
                        Text(formattedDate)
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
                    Text(customerEmail)
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
                    Text(formattedTime)
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.7))
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "person.2")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "2b7fff"))
                    Text("\(reservation.guest_count) Guests")
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
            if let special = reservation.special_requests, !special.isEmpty {
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
            if statusEnum == .pending {
                HStack(spacing: 12) {
                    Button(action: onConfirm) {
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
                    
                    Button(action: onDecline) {
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
            } else if statusEnum == .confirmed {
                Button(action: onCancel) {
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
        .background(
            Color(hex: "1e293b"),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color(hex: "2b7fff").opacity(0.15), radius: 32, x: 0, y: 8)
    }
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
        case .confirmed: return Color(hex: "22c55e").opacity(0.1)
        case .pending: return Color(hex: "eab308").opacity(0.1)
        case .cancelled: return Color(hex: "ef4444").opacity(0.1)
        }
    }
    
    var borderColor: Color {
        switch self {
        case .confirmed: return Color(hex: "22c55e").opacity(0.3)
        case .pending: return Color(hex: "eab308").opacity(0.3)
        case .cancelled: return Color(hex: "ef4444").opacity(0.3)
        }
    }
}

#Preview {
    OwnerReservationsScreen()
}
