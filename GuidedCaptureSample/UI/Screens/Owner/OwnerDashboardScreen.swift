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
    let day: String
    let value: Double
}

struct ViewsData: Identifiable {
    let id = UUID()
    let day: String
    let views: Int
    let orders: Int
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
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: Color(hex: "2b7fff").opacity(0.15), radius: 32, x: 0, y: 8)
    }
}

// MARK: - Screen
struct OwnerDashboardScreen: View {
    // MARK: - Data
    let stats: [DashboardStat] = [
        DashboardStat(
            id: "revenue",
            title: "Total Revenue",
            value: "$24,580",
            change: "+12.5%",
            isPositive: true,
            icon: "dollarsign",
            gradientColors: [Color(hex: "2b7fff"), Color(hex: "3b82f6")]
        ),
        DashboardStat(
            id: "views",
            title: "Menu Views",
            value: "8,432",
            change: "+8.2%",
            isPositive: true,
            icon: "eye",
            gradientColors: [Color(hex: "8b5cf6"), Color(hex: "a78bfa")]
        ),
        DashboardStat(
            id: "reservations",
            title: "Reservations",
            value: "156",
            change: "-3.1%",
            isPositive: false,
            icon: "calendar",
            gradientColors: [Color(hex: "10b981"), Color(hex: "34d399")]
        ),
        DashboardStat(
            id: "growth",
            title: "Growth Rate",
            value: "23.8%",
            change: "+5.4%",
            isPositive: true,
            icon: "chart.line.uptrend.xyaxis",
            gradientColors: [Color(hex: "f59e0b"), Color(hex: "fbbf24")]
        )
    ]
    
    let revenueData: [RevenueData] = [
        RevenueData(day: "Mon", value: 2400),
        RevenueData(day: "Tue", value: 3200),
        RevenueData(day: "Wed", value: 2800),
        RevenueData(day: "Thu", value: 3900),
        RevenueData(day: "Fri", value: 4800),
        RevenueData(day: "Sat", value: 5200),
        RevenueData(day: "Sun", value: 4100)
    ]
    
    let viewsData: [ViewsData] = [
        ViewsData(day: "Mon", views: 1200, orders: 450),
        ViewsData(day: "Tue", views: 1500, orders: 620),
        ViewsData(day: "Wed", views: 1100, orders: 380),
        ViewsData(day: "Thu", views: 1800, orders: 720),
        ViewsData(day: "Fri", views: 2200, orders: 980),
        ViewsData(day: "Sat", views: 2600, orders: 1150),
        ViewsData(day: "Sun", views: 1900, orders: 850)
    ]
    
    // MARK: - Body
    @State private var isLoading = true
    
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
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Dashboard")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundColor(.white)
                            Text("Welcome back! Here's your restaurant overview")
                                .font(.body)
                                .foregroundColor(Color.white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 24)
                        .skeleton(isLoading: isLoading)
                        
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
                                        
                                        // Value and Change
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(stat.value)
                                                .font(.title3)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                            
                                            HStack(spacing: 2) {
                                                Image(systemName: stat.isPositive ? "arrow.up" : "arrow.down")
                                                    .font(.system(size: 12))
                                                Text(stat.change)
                                                    .font(.caption)
                                            }
                                            .foregroundColor(stat.isPositive ? Color(hex: "4ade80") : Color(hex: "f87171"))
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
                                    ForEach(revenueData) { item in
                                        AreaMark(
                                            x: .value("Day", item.day),
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
                                            x: .value("Day", item.day),
                                            y: .value("Revenue", item.value)
                                        )
                                        .foregroundStyle(Color(hex: "2b7fff"))
                                        .interpolationMethod(.catmullRom)
                                        .lineStyle(StrokeStyle(lineWidth: 2))
                                    }
                                }
                                .chartXAxis {
                                    AxisMarks(values: .automatic) { _ in
                                        AxisValueLabel()
                                            .foregroundStyle(Color.white.opacity(0.4))
                                            .font(.caption)
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
                        
                        // Views & Orders Chart
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Menu Views vs Orders")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            DashboardCard {
                                VStack {
                                    Chart {
                                        ForEach(viewsData) { item in
                                            BarMark(
                                                x: .value("Day", item.day),
                                                y: .value("Count", item.views)
                                            )
                                            .foregroundStyle(Color(hex: "2b7fff"))
                                            .cornerRadius(4)
                                            .position(by: .value("Type", "Views"))
                                            
                                            BarMark(
                                                x: .value("Day", item.day),
                                                y: .value("Count", item.orders)
                                            )
                                            .foregroundStyle(Color(hex: "8b5cf6"))
                                            .cornerRadius(4)
                                            .position(by: .value("Type", "Orders"))
                                        }
                                    }
                                    .chartXAxis {
                                        AxisMarks(values: .automatic) { _ in
                                            AxisValueLabel()
                                                .foregroundStyle(Color.white.opacity(0.4))
                                                .font(.caption)
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
                                            Text("Views")
                                                .font(.caption)
                                                .foregroundColor(Color.white.opacity(0.6))
                                        }
                                        
                                        HStack(spacing: 8) {
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(Color(hex: "8b5cf6"))
                                                .frame(width: 12, height: 12)
                                            Text("Orders")
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
                        HStack(spacing: 12) {
                            Button(action: { /* Add New Dish */ }) {
                                Text("Add New Dish")
                                    .font(.system(size: 14, weight: .medium))
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
                            
                            Button(action: { /* View Reports */ }) {
                                Text("View Reports")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                    )
                            }
                        }
                        .padding(.bottom, 120) // Extra padding for bottom tab bar
                        .skeleton(isLoading: isLoading)
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: 500) // Constrain width for larger screens
                    .frame(width: geometry.size.width) // Ensure full width alignment
                }
                .onAppear {
                    // Simulate loading
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            isLoading = false
                        }
                    }
                }
            }
        }
    }
}
