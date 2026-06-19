import SwiftUI
import Charts

// MARK: - Enums & Models
enum DashboardRange: String, CaseIterable, Identifiable {
    case today = "Today"
    case sevenDays = "7 Days"
    case thirtyDays = "Last 4 Weeks"
    var id: String { self.rawValue }
}

struct DashboardStat: Identifiable {
    let id: String
    let title: String
    let value: String
    let trend: String?
    let isPositiveTrend: Bool?
    let icon: String
    let gradientColors: [Color]
}

struct SalesTrendPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let isCurrent: Bool
    let orderIndex: Int
}

struct OrderGroup: Identifiable {
    let id = UUID()
    let title: String
    let completedRevenue: Double
    let orders: [Order]
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

struct OrderAccordionView: View {
    let group: OrderGroup
    @State private var isExpanded: Bool = true
    var onOrderTap: (Order) -> Void
    
    var body: some View {
        DashboardCard {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(spacing: 12) {
                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.vertical, 8)
                    
                    if group.orders.isEmpty {
                        Text("No orders in this period")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.vertical, 16)
                    } else {
                        ForEach(group.orders) { order in
                            Button(action: { onOrderTap(order) }) {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 8) {
                                            Text(order.displayOrderNumber)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(.white)
                                            
                                            Text(order.customer_name ?? "Guest")
                                                .font(.system(size: 14))
                                                .foregroundColor(.white.opacity(0.8))
                                        }
                                        
                                        Text(formatOrderTime(order.created_at))
                                            .font(.system(size: 12))
                                            .foregroundColor(.white.opacity(0.4))
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(String(format: "$%.2f", order.total))
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(.white)
                                        
                                        OrderStatusBadge(status: order.status)
                                    }
                                }
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            
                            if order.id != group.orders.last?.id {
                                Divider()
                                    .background(Color.white.opacity(0.05))
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("\(group.orders.count) \(group.orders.count == 1 ? "order" : "orders")")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    Spacer()
                    
                    Text(String(format: "$%.2f", group.completedRevenue))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color(hex: "2b7fff"))
                        .padding(.trailing, 8)
                }
            }
            .accentColor(.white.opacity(0.7))
        }
    }
    
    private func formatOrderTime(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        var date = formatter.date(from: isoString)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            date = formatter.date(from: isoString)
        }
        guard let d = date else { return "" }
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        return fmt.string(from: d)
    }
}

struct OrderStatusBadge: View {
    let status: OrderStatus
    
    var body: some View {
        Text(status.displayName.uppercased())
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(badgeColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(badgeColor.opacity(0.12))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(badgeColor.opacity(0.3), lineWidth: 1))
    }
    
    private var badgeColor: Color {
        switch status {
        case .pending: return .gray
        case .received, .placed: return Color(hex: "3b82f6")
        case .confirmed, .accepted: return Color(hex: "2b7fff")
        case .preparing: return Color(hex: "f59e0b")
        case .ready: return Color(hex: "10b981")
        case .completed: return Color(hex: "10b981")
        case .cancelled: return Color(hex: "ef4444")
        }
    }
}

// MARK: - Screen
struct OwnerDashboardScreen: View {
    @StateObject private var supabase = SupabaseManager.shared
    @StateObject private var viewModel = DashboardViewModel()
    
    var onTabSelect: ((Int) -> Void)? = nil
    
    // MARK: - States
    @State private var selectedRange: DashboardRange = .sevenDays
    @State private var restaurant: Restaurant? = nil
    @State private var orders: [Order] = []
    @State private var dishes: [Dish] = []
    @State private var isLoading = true
    @State private var isRefreshing = false
    @State private var errorMessage: String? = nil
    @State private var selectedOrderForDetail: Order? = nil
    @State private var fetchTask: Task<Void, Never>? = nil
    
    // Computed properties moved to DashboardViewModel
    
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
                    
                    if !isLoading {
                        UploadQueueView(dishes: dishes) { dish in
                            Task {
                                try? await SupabaseManager.shared.updateDishPartial(id: dish.id, generationStatus: "pending")
                                loadDashboardData()
                            }
                        }
                    }
                    
                    // Range Selector
                    HStack(spacing: 0) {
                        ForEach(DashboardRange.allCases) { range in
                            let isSelected = selectedRange == range
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    selectedRange = range
                                    viewModel.update(orders: orders, range: range)
                                }
                            } label: {
                                Text(range.rawValue)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        isSelected
                                        ? LinearGradient(colors: [Color(hex: "2b7fff"), Color(hex: "1a5fd9")], startPoint: .leading, endPoint: .trailing)
                                        : LinearGradient(colors: [Color.clear, Color.clear], startPoint: .leading, endPoint: .trailing)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(4)
                    .background(Color(hex: "1e293b"))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .padding(.bottom, 8)
                    
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
                                loadDashboardData()
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
                        ForEach(viewModel.stats) { stat in
                            DashboardCard {
                                VStack(alignment: .leading, spacing: 12) {
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
                                            .shadow(color: stat.gradientColors[0].opacity(0.3), radius: 12, x: 0, y: 8)
                                        
                                        Image(systemName: stat.icon)
                                            .font(.system(size: 20))
                                            .foregroundColor(.white)
                                    }
                                    .padding(.bottom, 4)
                                    
                                    Text(stat.title)
                                        .font(.caption)
                                        .foregroundColor(Color.white.opacity(0.6))
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(stat.value)
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                        
                                        if let trend = stat.trend, let isPositive = stat.isPositiveTrend {
                                            Text(trend)
                                                .font(.caption2)
                                                .fontWeight(.medium)
                                                .foregroundColor(isPositive ? Color(hex: "4ade80") : Color(hex: "ef4444"))
                                                .padding(.top, 2)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .skeleton(isLoading: isLoading)
                    
                    // Sales Trend Chart
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sales Trend")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        DashboardCard {
                            if viewModel.isTodayChartSparse {
                                VStack(spacing: 12) {
                                    Image(systemName: "chart.bar.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(Color.white.opacity(0.2))
                                    Text("Hourly trends require at least 5 orders today.")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color.white.opacity(0.6))
                                        .multilineTextAlignment(.center)
                                    Text("Keep up the great work!")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Color(hex: "2b7fff"))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 200)
                            } else {
                                Chart {
                                    ForEach(viewModel.chartData) { item in
                                        BarMark(
                                            x: .value("Period", item.label),
                                            y: .value("Revenue", item.value)
                                        )
                                        .foregroundStyle(item.isCurrent ? Color(hex: "2b7fff") : Color(hex: "2b7fff").opacity(0.25))
                                        .cornerRadius(4)
                                    }
                                }
                                .chartXAxis {
                                    AxisMarks(values: .automatic) { value in
                                        AxisValueLabel {
                                            if let label = value.as(String.self) {
                                                Text(label)
                                                    .foregroundStyle(Color.white.opacity(0.4))
                                                    .font(.system(size: 10))
                                                    .rotationEffect(.degrees(selectedRange == .today ? -45 : 0))
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
                    }
                    .skeleton(isLoading: isLoading)
                    
                    // Orders Accordions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Orders")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        let groups = viewModel.accordionGroups
                        if groups.isEmpty {
                            DashboardCard {
                                VStack(spacing: 12) {
                                    Image(systemName: "tray.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(Color.white.opacity(0.2))
                                    Text("No orders in this time range.")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color.white.opacity(0.6))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 32)
                            }
                        } else {
                            ForEach(groups) { group in
                                OrderAccordionView(group: group) { order in
                                    selectedOrderForDetail = order
                                }
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
                    .padding(.bottom, 120)
                    .skeleton(isLoading: isLoading)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: 500)
                .frame(maxWidth: .infinity)
            }
            .refreshable {
                loadDashboardData()
            }
        }
        .task {
            isLoading = true
            loadDashboardData()
            withAnimation {
                isLoading = false
            }
            
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
                if selectedOrderForDetail == nil {
                    loadOrdersQuietly()
                }
            }
        }
        .sheet(item: $selectedOrderForDetail) { order in
            OwnerOrderDetailSheet(
                order: order,
                onAccept: { updateOrderStatus(order, to: .confirmed) },
                onReject: { updateOrderStatus(order, to: .cancelled) },
                onComplete: { updateOrderStatus(order, to: .completed) }
            )
        }
    }
    
    private func loadDashboardData() {
        guard !isRefreshing else { return }
        isRefreshing = true
        
        guard let userId = supabase.currentUser?.id else {
            self.errorMessage = "User not authenticated"
            self.isRefreshing = false
            return
        }
        
        fetchTask?.cancel()
        fetchTask = Task {
            do {
                let fetchedRestaurant = try await supabase.fetchOwnerRestaurant()
                if Task.isCancelled { return }
                
                let cal = Calendar.current
                let startOfToday = cal.startOfDay(for: Date())
                guard let sixtyDaysAgo = cal.date(byAdding: .day, value: -59, to: startOfToday) else { return }
                
                let fetchedOrders = try await supabase.fetchDashboardOrders(restaurantId: userId, startDate: sixtyDaysAgo)
                if Task.isCancelled { return }
                
                let fetchedDishes = try await supabase.fetchOwnerDishes()
                if Task.isCancelled { return }
                
                await MainActor.run {
                    self.restaurant = fetchedRestaurant
                    self.orders = fetchedOrders
                    self.dishes = fetchedDishes
                    self.errorMessage = nil
                    self.viewModel.update(orders: fetchedOrders, range: self.selectedRange)
                    self.isRefreshing = false
                    self.isLoading = false
                }
            } catch {
                if Task.isCancelled { return }
                print("❌ Error loading dashboard data: \(error.localizedDescription)")
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isRefreshing = false
                }
            }
        }
    }
    
    private func loadOrdersQuietly() {
        guard let userId = supabase.currentUser?.id, let currentRestaurant = self.restaurant else { return }
        
        Task {
            do {
                async let fetchedOrdersPromise = SupabaseManager.shared.fetchRestaurantOrders(restaurantId: currentRestaurant.id)
                async let fetchedDishesPromise = SupabaseManager.shared.fetchOwnerDishes()
                
                let fetchedOrders = try await fetchedOrdersPromise
                let fetchedDishes = try await fetchedDishesPromise
                
                await MainActor.run {
                    self.orders = fetchedOrders
                    self.dishes = fetchedDishes
                    self.viewModel.update(orders: fetchedOrders, range: self.selectedRange)
                    self.isLoading = false
                }
            } catch {
                print("Quiet fetch error: \(error)")
            }
        }
    }
    
    private func updateOrderStatus(_ order: Order, to status: OrderStatus) {
        Task {
            do {
                _ = try await supabase.updateOrderStatus(orderId: order.id, newStatus: status)
                await MainActor.run {
                    if let idx = orders.firstIndex(where: { $0.id == order.id }) {
                        let newOrder = Order(
                            id: order.id,
                            restaurantId: order.restaurant_id,
                            status: status,
                            paymentMethod: order.payment_method,
                            subtotal: order.subtotal,
                            tax: order.tax,
                            total: order.total,
                            specialNotes: order.special_notes,
                            customerName: order.customer_name,
                            customerPhone: order.customer_phone,
                            items: order.items ?? []
                        )
                        orders[idx] = newOrder
                        self.viewModel.update(orders: orders, range: self.selectedRange)
                    }
                    if selectedOrderForDetail?.id == order.id {
                        selectedOrderForDetail = nil
                    }
                }
            } catch {
                print("Status update error: \(error)")
            }
        }
    }
}
import SwiftUI

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var stats: [DashboardStat] = []
    @Published var chartData: [SalesTrendPoint] = []
    @Published var accordionGroups: [OrderGroup] = []
    @Published var isTodayChartSparse: Bool = false
    
    // Performance: Avoid re-calculating if inputs haven't logically changed.
    private var lastOrdersHash: Int? = nil
    private var lastRange: DashboardRange? = nil
    private var lastCalculatedAt: Date = .distantPast
    
    func update(orders: [Order], range: DashboardRange) {
        // Simple hash based on count and most recent order id + status
        var currentHash = orders.count
        if let first = orders.first {
            currentHash ^= first.id.hashValue
            currentHash ^= first.status.rawValue.hashValue
        }
        
        let now = Date()
        
        // Skip recalculation if inputs match AND we calculated less than 60 seconds ago (or range is the same)
        // (We might want to recalculate if the clock crosses hour boundaries, but for now this is fine)
        if currentHash == lastOrdersHash && range == lastRange && now.timeIntervalSince(lastCalculatedAt) < 60 {
            return
        }
        
        self.lastOrdersHash = currentHash
        self.lastRange = range
        self.lastCalculatedAt = now
        
        // Push heavy lifting to background
        Task.detached {
            let result = Self.calculateMetrics(orders: orders, range: range, now: now)
            await MainActor.run {
                self.stats = result.stats
                self.chartData = result.chartData
                self.accordionGroups = result.groups
                self.isTodayChartSparse = result.isSparse
            }
        }
    }
    
    nonisolated private static func parseISO8601Date(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return isoFormatter.date(from: dateString) ?? ISO8601DateFormatter().date(from: dateString)
    }
    
    nonisolated private static func getRanges(range: DashboardRange, now: Date) -> (current: (start: Date, end: Date), previous: (start: Date, end: Date)) {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: now)
        
        let currentStart: Date
        switch range {
        case .today:
            currentStart = startOfToday
        case .sevenDays:
            currentStart = cal.date(byAdding: .day, value: -6, to: startOfToday)!
        case .thirtyDays:
            currentStart = cal.date(byAdding: .day, value: -27, to: startOfToday)!
        }
        let currentRange = (start: currentStart, end: now)
        
        let previousStart: Date
        let previousEnd: Date
        switch range {
        case .today:
            previousStart = cal.date(byAdding: .day, value: -1, to: startOfToday)!
            previousEnd = startOfToday
        case .sevenDays:
            previousStart = cal.date(byAdding: .day, value: -7, to: currentStart)!
            previousEnd = currentStart
        case .thirtyDays:
            previousStart = cal.date(byAdding: .day, value: -28, to: currentStart)!
            previousEnd = currentStart
        }
        
        return (currentRange, (start: previousStart, end: previousEnd))
    }
    
    struct CalculationResult {
        let stats: [DashboardStat]
        let chartData: [SalesTrendPoint]
        let groups: [OrderGroup]
        let isSparse: Bool
    }
    
    // Extracted into a static, Sendable-safe function
    nonisolated private static func calculateMetrics(orders: [Order], range: DashboardRange, now: Date) -> CalculationResult {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: now)
        
        let (currentPeriodRange, previousPeriodRange) = getRanges(range: range, now: now)
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // 2. Orders parsing
        let parsedOrders = orders.compactMap { order -> (Order, Date)? in
            guard let date = isoFormatter.date(from: order.created_at) ?? ISO8601DateFormatter().date(from: order.created_at) else { return nil }
            return (order, date)
        }
        
        let currentOrders = parsedOrders.filter {
            $0.1 >= currentPeriodRange.start && $0.1 < currentPeriodRange.end
        }.map { $0.0 }
        
        let previousOrders = parsedOrders.filter {
            $0.1 >= previousPeriodRange.start && $0.1 < previousPeriodRange.end
        }.map { $0.0 }
        
        // 1. Stats
        let currentCompleted = currentOrders.filter { $0.status == .completed }
        let prevCompleted = previousOrders.filter { $0.status == .completed }
        
        let currentRev = currentCompleted.reduce(0) { $0 + $1.total }
        let prevRev = prevCompleted.reduce(0) { $0 + $1.total }
        
        var trendStr: String? = nil
        var isPositive: Bool? = nil
        if prevRev > 0 {
            let diff = (currentRev - prevRev) / prevRev * 100
            isPositive = diff >= 0
            trendStr = String(format: "%@ %.0f%% vs previous", diff >= 0 ? "↑" : "↓", abs(diff))
        } else if currentRev > 0 {
            isPositive = true
            trendStr = "↑ 100% vs previous"
        }
        
        let totalCount = currentOrders.count
        let compCount = currentCompleted.count
        let aov = compCount > 0 ? (currentRev / Double(compCount)) : 0.0
        
        let compRate = totalCount > 0 ? (Double(compCount) / Double(totalCount) * 100) : 0.0
        let compRateStr = totalCount > 0 ? String(format: "%.0f%%", compRate) : "—"
        
        let computedStats = [
            DashboardStat(id: "revenue", title: "Revenue (Completed)", value: String(format: "$%.2f", currentRev), trend: trendStr, isPositiveTrend: isPositive, icon: "dollarsign", gradientColors: [Color(hex: "2b7fff"), Color(hex: "3b82f6")]),
            DashboardStat(id: "orders", title: "Total Orders", value: "\(totalCount)", trend: nil, isPositiveTrend: nil, icon: "cart.fill", gradientColors: [Color(hex: "8b5cf6"), Color(hex: "a78bfa")]),
            DashboardStat(id: "aov", title: "Avg Order Value", value: String(format: "$%.2f", aov), trend: nil, isPositiveTrend: nil, icon: "chart.bar.fill", gradientColors: [Color(hex: "f59e0b"), Color(hex: "fbbf24")]),
            DashboardStat(id: "completion", title: "Completion Rate", value: compRateStr, trend: nil, isPositiveTrend: nil, icon: "checkmark.seal.fill", gradientColors: [Color(hex: "10b981"), Color(hex: "34d399")])
        ]
        
        // 2. Chart Data
        var points: [SalesTrendPoint] = []
        switch range {
        case .today:
            let start = startOfToday
            let currentHour = cal.component(.hour, from: now)
            let currentBucketIdx = currentHour / 2
            
            for i in 0..<12 {
                let bucketStart = cal.date(byAdding: .hour, value: i * 2, to: start)!
                let bucketEnd = cal.date(byAdding: .hour, value: (i + 1) * 2, to: start)!
                
                let rev = currentCompleted.filter {
                    guard let d = parseISO8601Date($0.created_at) else { return false }
                    return d >= bucketStart && d < bucketEnd
                }.reduce(0) { $0 + $1.total }
                
                let df = DateFormatter()
                df.dateFormat = "h a"
                let label = df.string(from: bucketStart)
                
                points.append(SalesTrendPoint(label: label, value: rev, isCurrent: i == currentBucketIdx, orderIndex: i))
            }
            
        case .sevenDays:
            for i in 0..<7 {
                let dayStart = cal.date(byAdding: .day, value: -6 + i, to: startOfToday)!
                let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!
                
                let rev = currentCompleted.filter {
                    guard let d = parseISO8601Date($0.created_at) else { return false }
                    return d >= dayStart && d < dayEnd
                }.reduce(0) { $0 + $1.total }
                
                let df = DateFormatter()
                df.dateFormat = "EEE"
                let label = df.string(from: dayStart)
                
                points.append(SalesTrendPoint(label: label, value: rev, isCurrent: i == 6, orderIndex: i))
            }
            
        case .thirtyDays:
            for i in 0..<4 {
                let offsetStart = -27 + (i * 7)
                let weekStart = cal.date(byAdding: .day, value: offsetStart, to: startOfToday)!
                let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart)!
                
                let rev = currentCompleted.filter {
                    guard let d = parseISO8601Date($0.created_at) else { return false }
                    return d >= weekStart && d < weekEnd
                }.reduce(0) { $0 + $1.total }
                
                let df = DateFormatter()
                df.dateFormat = "MMM d"
                let label = df.string(from: weekStart)
                
                points.append(SalesTrendPoint(label: label, value: rev, isCurrent: i == 3, orderIndex: i))
            }
        }
        
        // 3. Accordion Groups
        var groups: [OrderGroup] = []
        switch range {
        case .today:
            let compRev = currentCompleted.reduce(0) { $0 + $1.total }
            groups.append(OrderGroup(title: "Today's Orders", completedRevenue: compRev, orders: currentOrders.sorted(by: { $0.created_at > $1.created_at })))
            
        case .sevenDays:
            for i in (0..<7).reversed() {
                let dayStart = cal.date(byAdding: .day, value: -6 + i, to: startOfToday)!
                let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!
                
                let dayOrders = currentOrders.filter {
                    guard let d = parseISO8601Date($0.created_at) else { return false }
                    return d >= dayStart && d < dayEnd
                }.sorted(by: { $0.created_at > $1.created_at })
                
                if dayOrders.isEmpty { continue }
                
                let compRev = dayOrders.filter({ $0.status == .completed }).reduce(0) { $0 + $1.total }
                
                var title = ""
                if i == 6 { title = "Today" }
                else if i == 5 { title = "Yesterday" }
                else {
                    let df = DateFormatter()
                    df.dateFormat = "EEEE"
                    title = df.string(from: dayStart)
                }
                
                groups.append(OrderGroup(title: title, completedRevenue: compRev, orders: dayOrders))
            }
            
        case .thirtyDays:
            for i in (0..<4).reversed() {
                let offsetStart = -27 + (i * 7)
                let weekStart = cal.date(byAdding: .day, value: offsetStart, to: startOfToday)!
                let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart)!
                
                let weekOrders = currentOrders.filter {
                    guard let d = parseISO8601Date($0.created_at) else { return false }
                    return d >= weekStart && d < weekEnd
                }.sorted(by: { $0.created_at > $1.created_at })
                
                if weekOrders.isEmpty { continue }
                
                let compRev = weekOrders.filter({ $0.status == .completed }).reduce(0) { $0 + $1.total }
                
                let df = DateFormatter()
                df.dateFormat = "MMM d"
                let endDf = DateFormatter()
                endDf.dateFormat = "d"
                let weekEndMinusOne = cal.date(byAdding: .day, value: -1, to: weekEnd)!
                
                let title = i == 3 ? "This Week" : "\(df.string(from: weekStart)) – \(endDf.string(from: weekEndMinusOne))"
                
                groups.append(OrderGroup(title: title, completedRevenue: compRev, orders: weekOrders))
            }
        }
        
        let sparse = (range == .today && currentOrders.count < 5)
        
        return CalculationResult(stats: computedStats, chartData: points, groups: groups, isSparse: sparse)
    }
}
