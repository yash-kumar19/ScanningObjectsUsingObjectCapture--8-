import SwiftUI
import Charts

// MARK: - Data Models
struct DashboardStat: Identifiable {
    let id: String
    let title: String
    let value: String
    let change: String
    let isPositive: Bool
    let icon: String
    let gradientColors: [Color]
}

struct RevenueData: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct TrendData: Identifiable {
    let id = UUID()
    let date: Date
    let orders: Int
    let reservations: Int
}

// MARK: - Helper Components
struct DashboardCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(16)
            .background(
                Color(hex: "1e293b"), // Dark non-glass background
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: Color(hex: "2b7fff").opacity(0.15), radius: 32, x: 0, y: 8)
    }
}

// MARK: - Screen
struct OwnerDashboardScreen: View {
    @StateObject private var supabase = SupabaseManager.shared
    
    var onTabSelect: ((Int) -> Void)? = nil
    
    // MARK: - States
    @State private var restaurant: Restaurant? = nil
    @State private var orders: [Order] = []
    @State private var reservations: [Reservation] = []
    @State private var dishes: [Dish] = []
    @State private var isLoading = true
    @State private var isRefreshing = false
    @State private var errorMessage: String? = nil
    
    // MARK: - Computed Properties
    var stats: [DashboardStat] {
        let completedOrders = orders.filter { $0.status == .completed }
        let totalRevenue = completedOrders.reduce(0.0) { $0 + $1.total }
        let totalOrdersCount = orders.count
        let totalReservationsCount = reservations.count
        let completedCount = completedOrders.count
        let avgOrderValue = completedCount > 0 ? (totalRevenue / Double(completedCount)) : 0.0
        
        return [
            DashboardStat(
                id: "revenue",
                title: "Total Revenue",
                value: String(format: "$%.2f", totalRevenue),
                change: "Live",
                isPositive: true,
                icon: "dollarsign",
                gradientColors: [Color(hex: "2b7fff"), Color(hex: "3b82f6")]
            ),
            DashboardStat(
                id: "orders",
                title: "Total Orders",
                value: "\(totalOrdersCount)",
                change: "Live",
                isPositive: true,
                icon: "cart.fill",
                gradientColors: [Color(hex: "8b5cf6"), Color(hex: "a78bfa")]
            ),
            DashboardStat(
                id: "reservations",
                title: "Reservations",
                value: "\(totalReservationsCount)",
                change: "Live",
                isPositive: true,
                icon: "calendar",
                gradientColors: [Color(hex: "10b981"), Color(hex: "34d399")]
            ),
            DashboardStat(
                id: "avg_order",
                title: "Avg Order Value",
                value: String(format: "$%.2f", avgOrderValue),
                change: "Live",
                isPositive: true,
                icon: "chart.bar.fill",
                gradientColors: [Color(hex: "f59e0b"), Color(hex: "fbbf24")]
            )
        ]
    }
    
    var computedRevenueData: [RevenueData] {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        guard let startDate = calendar.date(byAdding: .day, value: -6, to: startOfToday) else { return [] }
        
        var dayDates: [Date] = []
        for i in 0..<7 {
            if let d = calendar.date(byAdding: .day, value: i, to: startDate) {
                dayDates.append(calendar.startOfDay(for: d))
            }
        }
        
        let localFormatter = DateFormatter()
        localFormatter.dateFormat = "yyyy-MM-dd"
        localFormatter.timeZone = TimeZone.current
        
        return dayDates.map { date in
            let localKey = localFormatter.string(from: date)
            
            let dayRevenue = orders.filter { order in
                guard order.status == .completed,
                      let orderDate = parseISO8601Date(order.created_at) else { return false }
                return localFormatter.string(from: orderDate) == localKey
            }.reduce(0.0) { $0 + $1.total }
            
            return RevenueData(date: date, value: dayRevenue)
        }
    }
    
    var computedTrendData: [TrendData] {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        guard let startDate = calendar.date(byAdding: .day, value: -6, to: startOfToday) else { return [] }
        
        var dayDates: [Date] = []
        for i in 0..<7 {
            if let d = calendar.date(byAdding: .day, value: i, to: startDate) {
                dayDates.append(calendar.startOfDay(for: d))
            }
        }
        
        let localFormatter = DateFormatter()
        localFormatter.dateFormat = "yyyy-MM-dd"
        localFormatter.timeZone = TimeZone.current
        
        let utcFormatter = DateFormatter()
        utcFormatter.dateFormat = "yyyy-MM-dd"
        utcFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        return dayDates.map { date in
            let localKey = localFormatter.string(from: date)
            let utcKey = utcFormatter.string(from: date)
            
            let dayOrdersCount = orders.filter { order in
                guard let orderDate = parseISO8601Date(order.created_at) else { return false }
                return localFormatter.string(from: orderDate) == localKey
            }.count
            
            let dayReservationsCount = reservations.filter { res in
                return res.reservation_date == utcKey
            }.count
            
            return TrendData(date: date, orders: dayOrdersCount, reservations: dayReservationsCount)
        }
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dashboard")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.white)
                        
                        if isLoading {
                            Text("Loading your restaurant overview...")
                                .font(.body)
                                .foregroundColor(Color.white.opacity(0.6))
                        } else if let restaurant = restaurant {
                            Text("Welcome back to \(restaurant.name)! Here's your overview")
                                .font(.body)
                                .foregroundColor(Color.white.opacity(0.6))
                        } else {
                            Text("Welcome back! Here's your restaurant overview")
                                .font(.body)
                                .foregroundColor(Color.white.opacity(0.6))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 24)
                    .skeleton(isLoading: isLoading)
                        
                        // Error Recovery Banner
                        if let error = errorMessage {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                                    .lineLimit(2)
                                Spacer()
                                Button(action: {
                                    Task {
                                        await loadDashboardData()
                                    }
                                }) {
                                    Text("Retry")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.white.opacity(0.15))
                                        .cornerRadius(8)
                                }
                            }
                            .padding()
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                        }
                        
                        // Stats Grid
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                            ForEach(stats) { stat in
                                DashboardCard {
                                    VStack(alignment: .leading, spacing: 12) {
                                        // Icon
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(
                                                    LinearGradient(
                                                        colors: stat.gradientColors,
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(width: 40, height: 40)
                                                .shadow(color: Color(hex: "2b7fff").opacity(0.3), radius: 12, x: 0, y: 8)
                                            
                                            Image(systemName: stat.icon)
                                                .font(.system(size: 20))
                                                .foregroundColor(.white)
                                        }
                                        .padding(.bottom, 4)
                                        
                                        // Label
                                        Text(stat.title)
                                            .font(.caption)
                                            .foregroundColor(Color.white.opacity(0.6))
                                        
                                        // Value and Live status
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(stat.value)
                                                .font(.title3)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                            
                                            HStack(spacing: 2) {
                                                Circle()
                                                    .fill(Color(hex: "4ade80"))
                                                    .frame(width: 6, height: 6)
                                                Text(stat.change)
                                                    .font(.caption)
                                            }
                                            .foregroundColor(Color(hex: "4ade80"))
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .skeleton(isLoading: isLoading)
                        
                        // Revenue Chart
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Weekly Revenue")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            DashboardCard {
                                Chart {
                                    ForEach(computedRevenueData) { item in
                                        AreaMark(
                                            x: .value("Day", item.date),
                                            y: .value("Revenue", item.value)
                                        )
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [Color(hex: "2b7fff").opacity(0.3), Color(hex: "2b7fff").opacity(0)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .interpolationMethod(.catmullRom)
                                        
                                        LineMark(
                                            x: .value("Day", item.date),
                                            y: .value("Revenue", item.value)
                                        )
                                        .foregroundStyle(Color(hex: "2b7fff"))
                                        .interpolationMethod(.catmullRom)
                                        .lineStyle(StrokeStyle(lineWidth: 2))
                                    }
                                }
                                .chartXAxis {
                                    AxisMarks(values: .stride(by: .day, count: 1)) { value in
                                        if let date = value.as(Date.self) {
                                            AxisValueLabel {
                                                Text(date, format: .dateTime.weekday(.abbreviated))
                                                    .foregroundStyle(Color.white.opacity(0.4))
                                                    .font(.caption)
                                            }
                                        }
                                    }
                                }
                                .chartYAxis {
                                    AxisMarks(values: .automatic) { _ in
                                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [5]))
                                            .foregroundStyle(Color.white.opacity(0.05))
                                        AxisValueLabel()
                                            .foregroundStyle(Color.white.opacity(0.4))
                                            .font(.caption)
                                    }
                                }
                                .frame(height: 200)
                            }
                        }
                        .skeleton(isLoading: isLoading)
                        
                        // Orders vs Reservations Chart
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Orders vs Reservations Trend")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            DashboardCard {
                                VStack {
                                    Chart {
                                        ForEach(computedTrendData) { item in
                                            BarMark(
                                                x: .value("Day", item.date),
                                                y: .value("Count", item.orders)
                                            )
                                            .foregroundStyle(Color(hex: "2b7fff"))
                                            .cornerRadius(4)
                                            .position(by: .value("Type", "Orders"))
                                            
                                            BarMark(
                                                x: .value("Day", item.date),
                                                y: .value("Count", item.reservations)
                                            )
                                            .foregroundStyle(Color(hex: "10b981"))
                                            .cornerRadius(4)
                                            .position(by: .value("Type", "Reservations"))
                                        }
                                    }
                                    .chartXAxis {
                                        AxisMarks(values: .stride(by: .day, count: 1)) { value in
                                            if let date = value.as(Date.self) {
                                                AxisValueLabel {
                                                    Text(date, format: .dateTime.weekday(.abbreviated))
                                                        .foregroundStyle(Color.white.opacity(0.4))
                                                        .font(.caption)
                                                }
                                            }
                                        }
                                    }
                                    .chartYAxis {
                                        AxisMarks(values: .automatic) { _ in
                                            AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [5]))
                                                .foregroundStyle(Color.white.opacity(0.05))
                                            AxisValueLabel()
                                                .foregroundStyle(Color.white.opacity(0.4))
                                                .font(.caption)
                                        }
                                    }
                                    .frame(height: 200)
                                    
                                    // Legend
                                    HStack(spacing: 24) {
                                        HStack(spacing: 8) {
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(Color(hex: "2b7fff"))
                                                .frame(width: 12, height: 12)
                                            Text("Orders")
                                                .font(.caption)
                                                .foregroundColor(Color.white.opacity(0.6))
                                        }
                                        
                                        HStack(spacing: 8) {
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(Color(hex: "10b981"))
                                                .frame(width: 12, height: 12)
                                            Text("Reservations")
                                                .font(.caption)
                                                .foregroundColor(Color.white.opacity(0.6))
                                        }
                                    }
                                    .padding(.top, 16)
                                }
                            }
                        }
                        .skeleton(isLoading: isLoading)
                        
                        // Quick Actions
                        VStack {
                            Button(action: {
                                onTabSelect?(1)
                                NotificationCenter.default.post(name: .ownerShouldShowAddDishSheet, object: nil)
                            }) {
                                Text("Add New Dish")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        LinearGradient(
                                            colors: [Color(hex: "2b7fff"), Color(hex: "3b82f6")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(16)
                                    .shadow(color: Color(hex: "2b7fff").opacity(0.4), radius: 12, x: 0, y: 4)
                            }
                        }
                        .padding(.bottom, 120) // Extra padding for bottom tab bar
                        .skeleton(isLoading: isLoading)
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: 500) // Constrain width for larger screens
                    .frame(maxWidth: .infinity) // Ensure full width alignment
                }
                .refreshable {
                    await loadDashboardData()
                }
            }
        .task {
            isLoading = true
            await loadDashboardData()
            withAnimation {
                isLoading = false
            }
            
            // Polling loop
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60 * 1_000_000_000) // 60s poll
                await loadDashboardData()
            }
        }
    }
    
    // MARK: - Private Methods
    private func loadDashboardData() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        
        guard let userId = supabase.currentUser?.id else {
            await MainActor.run {
                errorMessage = "User not authenticated"
            }
            return
        }
        
        do {
            // Step 1: Resolve restaurant ID first
            let fetchedRestaurant = try await supabase.fetchOwnerRestaurant()
            
            // Step 2: Set start date to normalized start-of-day 7 days ago (6 days back from today)
            let calendar = Calendar.current
            let now = Date()
            let startOfToday = calendar.startOfDay(for: now)
            guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: startOfToday) else { return }
            
            // Step 3: Fetch orders, reservations, and dishes in parallel
            async let ordersTask = supabase.fetchRestaurantOrders(restaurantId: userId, startDate: sevenDaysAgo)
            async let reservationsTask = supabase.fetchOwnerReservations(startDate: sevenDaysAgo)
            async let dishesTask = supabase.fetchOwnerDishes()
            
            let (fetchedOrders, fetchedReservations, fetchedDishes) = try await (ordersTask, reservationsTask, dishesTask)
            
            await MainActor.run {
                self.restaurant = fetchedRestaurant
                self.orders = fetchedOrders
                self.reservations = fetchedReservations
                self.dishes = fetchedDishes
                self.errorMessage = nil
            }
        } catch {
            print("❌ Error loading dashboard data: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    private func parseISO8601Date(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: string) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string)
    }
}
