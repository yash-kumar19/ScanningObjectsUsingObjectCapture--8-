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
    
    private static func parseISO8601Date(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        return DateHelper.isoFormatter.date(from: dateString)
    }
    
    private static func getRanges(range: DashboardRange, now: Date) -> (current: (start: Date, end: Date), previous: (start: Date, end: Date)) {
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
    private static func calculateMetrics(orders: [Order], range: DashboardRange, now: Date) -> CalculationResult {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: now)
        
        let (currentPeriodRange, previousPeriodRange) = getRanges(range: range, now: now)
        
        let currentOrders = orders.filter {
            guard let d = parseISO8601Date($0.created_at) else { return false }
            return d >= currentPeriodRange.start && d < currentPeriodRange.end
        }
        
        let previousOrders = orders.filter {
            guard let d = parseISO8601Date($0.created_at) else { return false }
            return d >= previousPeriodRange.start && d < previousPeriodRange.end
        }
        
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
