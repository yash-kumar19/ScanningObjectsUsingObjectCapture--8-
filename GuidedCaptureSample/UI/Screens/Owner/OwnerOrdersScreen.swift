//
//  OwnerOrdersScreen.swift
//  GuidedCaptureSample
//

import SwiftUI

// MARK: - Owner Orders Screen

struct OwnerOrdersScreen: View {
    @State private var selectedTab: OrderTab = .new
    @State private var orders: [Order] = []
    @State private var isLoading = false
    @State private var selectedOrder: Order? = nil
    @State private var pollingTimer: Timer? = nil
    @State private var liveDot = false

    @ObservedObject private var supabase = SupabaseManager.shared

    enum OrderTab: String, CaseIterable {
        case new = "New"
        case accepted = "Accepted"
    }

    var newOrders: [Order] {
        orders.filter { $0.status == .received || $0.status == .placed }
    }

    var acceptedOrders: [Order] {
        orders.filter { $0.status == .preparing || $0.status == .ready || $0.status == .confirmed || $0.status == .accepted }
    }

    var displayedOrders: [Order] {
        selectedTab == .new ? newOrders : acceptedOrders
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Orders")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    // Live Updates pill
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: "2b7fff"))
                            .frame(width: 8, height: 8)
                            .opacity(liveDot ? 1.0 : 0.3)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: liveDot)
                        Text("LIVE UPDATES")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: "2b7fff"))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(hex: "2b7fff").opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color(hex: "2b7fff").opacity(0.3), lineWidth: 1))
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 20)

                // Segmented Control
                OwnerOrderSegmentedControl(
                    selectedTab: $selectedTab,
                    newCount: newOrders.count,
                    acceptedCount: acceptedOrders.count
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                // Order List
                if isLoading && orders.isEmpty {
                    Spacer()
                    ProgressView().tint(.white)
                    Spacer()
                } else if displayedOrders.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: selectedTab == .new ? "tray" : "checkmark.circle")
                            .font(.system(size: 44))
                            .foregroundColor(.white.opacity(0.25))
                        Text(selectedTab == .new ? "No new orders" : "No accepted orders")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 14) {
                            ForEach(displayedOrders) { order in
                                OwnerOrderCard(
                                    order: order,
                                    isNew: selectedTab == .new,
                                    onAccept: {
                                        updateStatus(order, to: .preparing)
                                    },
                                    onViewDetail: {
                                        selectedOrder = order
                                    }
                                )
                            }
                            // Bottom padding for tab bar
                            Spacer().frame(height: 110)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                    }
                }
            }
        }
        .onAppear {
            liveDot = true
            loadOrders()
            startPolling()
        }
        .onDisappear {
            stopPolling()
        }
        .sheet(item: $selectedOrder) { order in
            OwnerOrderDetailSheet(
                order: order,
                onAccept: { updateStatus(order, to: .preparing) },
                onReject: { updateStatus(order, to: .cancelled) },
                onComplete: { updateStatus(order, to: .completed) }
            )
        }
    }

    // MARK: - Private

    private func loadOrders() {
        guard let restaurantId = supabase.currentUser?.id else { return }
        if orders.isEmpty { isLoading = true }
        Task {
            do {
                let fetched = try await supabase.fetchRestaurantOrders(restaurantId: restaurantId)
                await MainActor.run {
                    self.orders = fetched
                    self.isLoading = false
                }
            } catch {
                await MainActor.run { self.isLoading = false }
                print("❌ [OwnerOrders] Error fetching: \(error)")
            }
        }
    }

    private func startPolling() {
        stopPolling()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            loadOrders()
        }
    }

    private func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    private func updateStatus(_ order: Order, to status: OrderStatus) {
        Task {
            do {
                _ = try await supabase.updateOrderStatus(orderId: order.id, newStatus: status)
                await MainActor.run {
                    if selectedOrder?.id == order.id {
                        selectedOrder = nil
                    }
                    loadOrders()
                }
            } catch {
                print("❌ [OwnerOrders] Status update error: \(error)")
            }
        }
    }
}

// MARK: - Segmented Control

struct OwnerOrderSegmentedControl: View {
    @Binding var selectedTab: OwnerOrdersScreen.OrderTab
    let newCount: Int
    let acceptedCount: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(OwnerOrdersScreen.OrderTab.allCases, id: \.self) { tab in
                let isSelected = selectedTab == tab
                let count = tab == .new ? newCount : acceptedCount

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text(tab.rawValue)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                        Text("(\(count))")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .white.opacity(0.35))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        isSelected
                        ? LinearGradient(colors: [Color(hex: "2b7fff"), Color(hex: "1a5fd9")], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [Color.clear, Color.clear], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color(hex: "1e293b"))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Order Card

struct OwnerOrderCard: View {
    let order: Order
    let isNew: Bool
    var onAccept: () -> Void
    var onViewDetail: () -> Void

    var timeAgo: String {
        guard let date = ISO8601DateFormatter().date(from: order.created_at) else {
            return "Just now"
        }
        let diff = Date().timeIntervalSince(date)
        if diff < 60 { return "Just now" }
        let mins = Int(diff / 60)
        if mins < 60 { return "\(mins) min ago" }
        return "\(mins / 60) hr ago"
    }

    var itemCount: Int {
        order.items?.reduce(0) { $0 + $1.quantity } ?? 0
    }

    var previewItems: [OrderItem] {
        Array((order.items ?? []).prefix(2))
    }

    var extraCount: Int {
        max(0, (order.items?.count ?? 0) - 2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Top row: order number, time, payment badge
            HStack {
                HStack(spacing: 6) {
                    Text(order.displayOrderNumber)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Text("•")
                        .foregroundColor(.white.opacity(0.35))
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                    Text(timeAgo)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                }
                Spacer()
                // Payment method badge
                Text(order.payment_method == .cash ? "CASH" : order.payment_method.rawValue.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: "facc15"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(hex: "facc15").opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color(hex: "facc15").opacity(0.35), lineWidth: 1))
            }

            // Item count + total
            HStack(spacing: 6) {
                Text("\(itemCount) \(itemCount == 1 ? "item" : "items")  •")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
                Text(String(format: "$%.2f", order.total))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }

            // Item names
            VStack(alignment: .leading, spacing: 4) {
                ForEach(previewItems) { item in
                    HStack {
                        Text(item.name)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                        Text("x\(item.quantity)")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                if extraCount > 0 {
                    Text("+\(extraCount) more items...")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            // Action buttons
            if isNew {
                Button(action: onAccept) {
                    Text("Accept & Start Preparing")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(colors: [Color(hex: "2b7fff"), Color(hex: "1a5fd9")], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)

                Button(action: onViewDetail) {
                    Text("View Order →")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            } else {
                HStack {
                    Spacer()
                    Button(action: onViewDetail) {
                        Text("View Details →")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.55))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(Color(hex: "1e293b"))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Order Detail Sheet

struct OwnerOrderDetailSheet: View {
    let order: Order
    var onAccept: () -> Void
    var onReject: () -> Void
    var onComplete: () -> Void

    @Environment(\.dismiss) var dismiss

    var statusSteps: [(label: String, done: Bool, active: Bool)] {
        let statuses: [OrderStatus] = [.received, .preparing, .completed]
        return statuses.map { s in
            let isDone = stepCompleted(s)
            let isActive: Bool
            switch s {
            case .received:
                isActive = order.status == .received || order.status == .placed
            case .preparing:
                isActive = order.status == .preparing || order.status == .confirmed || order.status == .accepted || order.status == .ready
            case .completed:
                isActive = order.status == .completed
            default:
                isActive = order.status == s
            }
            return (label: s.displayName, done: isDone, active: isActive)
        }
    }

    func stepCompleted(_ step: OrderStatus) -> Bool {
        let order_idx = statusIndex(order.status)
        let step_idx = statusIndex(step)
        return step_idx < order_idx
    }

    func statusIndex(_ s: OrderStatus) -> Int {
        switch s {
        case .pending: return -1
        case .received, .placed: return 0
        case .confirmed, .accepted: return 1
        case .preparing: return 2
        case .ready: return 3
        case .completed: return 4
        case .cancelled: return -1
        }
    }

    var timeAgo: String {
        guard let date = ISO8601DateFormatter().date(from: order.created_at) else { return "Just now" }
        let diff = Date().timeIntervalSince(date)
        if diff < 60 { return "Just now" }
        let mins = Int(diff / 60)
        return "\(mins) min ago"
    }

    var formattedTime: String {
        guard let date = ISO8601DateFormatter().date(from: order.created_at) else { return "" }
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        return fmt.string(from: date)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Navigation header
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Text("Order \(order.displayOrderNumber)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)

                        Spacer()
                        // balance
                        Color.clear.frame(width: 36, height: 36)
                    }
                    .padding(.top, 20)

                    // Order Status Progress
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(statusSteps.enumerated()), id: \.offset) { idx, step in
                            HStack(alignment: .top, spacing: 14) {
                                // Timeline indicator
                                VStack(spacing: 0) {
                                    ZStack {
                                        Circle()
                                            .stroke(step.active ? Color(hex: "2b7fff") : Color.white.opacity(0.2), lineWidth: 2)
                                            .frame(width: 28, height: 28)
                                        if step.done {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(Color(hex: "2b7fff"))
                                        } else if step.active {
                                            Circle()
                                                .fill(Color(hex: "2b7fff"))
                                                .frame(width: 14, height: 14)
                                        }
                                    }
                                    if idx < statusSteps.count - 1 {
                                        Rectangle()
                                            .fill(Color.white.opacity(0.15))
                                            .frame(width: 2, height: 36)
                                    }
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(step.label)
                                        .font(.system(size: 15, weight: step.active ? .semibold : .regular))
                                        .foregroundColor(step.active ? Color(hex: "2b7fff") : .white.opacity(step.done ? 0.7 : 0.4))
                                    if step.active {
                                        Text(formattedTime)
                                            .font(.system(size: 12))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                }
                                .padding(.top, 4)
                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(16)
                    .background(Color(hex: "1e293b"))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))

                    // Customer Info
                    VStack(spacing: 12) {
                        HStack {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.1))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(order.customer_name ?? "Customer")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text("Order placed \(timeAgo)")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                            }
                            Spacer()
                            // Phone tap-to-call button
                            if let phone = order.customer_phone, !phone.isEmpty {
                                Button(action: {
                                    if let url = URL(string: "tel://\(phone.filter { $0.isNumber || $0 == "+" })") {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    Image(systemName: "phone.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                        .frame(width: 40, height: 40)
                                        .background(Color(hex: "22c55e").opacity(0.2))
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color(hex: "22c55e").opacity(0.4), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(action: {
                                        UIPasteboard.general.string = phone
                                    }) {
                                        Label("Copy Phone Number", systemImage: "doc.on.doc")
                                    }
                                }
                            }


                        }  // end HStack

                        // Special notes
                        if let notes = order.special_notes, !notes.isEmpty {
                            HStack(alignment: .top, spacing: 8) {
                                Text("\"")
                                    .font(.system(size: 18, weight: .heavy))
                                    .foregroundColor(Color(hex: "facc15").opacity(0.6))
                                Text(notes)
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "facc15").opacity(0.9))
                                    .italic()
                                Spacer()
                                Text("\"")
                                    .font(.system(size: 18, weight: .heavy))
                                    .foregroundColor(Color(hex: "facc15").opacity(0.6))
                            }
                            .padding(12)
                            .background(Color(hex: "facc15").opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "facc15").opacity(0.2), lineWidth: 1))
                        }
                    }
                    .padding(16)
                    .background(Color(hex: "1e293b"))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))

                    // Order Details
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Order Details")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)

                        if let items = order.items, !items.isEmpty {
                            ForEach(items) { item in
                                HStack {
                                    Text("\(item.quantity)x")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 26, height: 26)
                                        .background(Color(hex: "2b7fff").opacity(0.25))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))

                                    Text(item.name)
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.9))

                                    Spacer()

                                    Text(String(format: "$%.2f", item.totalPrice))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.75))
                                }
                            }
                        } else {
                            Text("No item details available")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.4))
                        }

                        Divider().background(Color.white.opacity(0.1)).padding(.vertical, 4)

                        HStack {
                            Text("Total")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            Text(String(format: "$%.2f", order.total))
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                        }

                        // Payment method
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("PAYMENT METHOD")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.4))
                                    .kerning(0.5)
                                Text(order.payment_method.displayName)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.85))
                            }
                            Spacer()
                            Text("UNPAID")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(hex: "2b7fff"))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color(hex: "2b7fff").opacity(0.15))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color(hex: "2b7fff").opacity(0.35), lineWidth: 1))
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.07), lineWidth: 1))
                    }
                    .padding(16)
                    .background(Color(hex: "1e293b"))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))

                    // Action buttons
                    if order.status == .received || order.status == .placed {
                        HStack(spacing: 12) {
                            Button {
                                onReject()
                                dismiss()
                            } label: {
                                Text("Reject")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.12), lineWidth: 1))
                            }
                            .buttonStyle(.plain)

                            Button {
                                onAccept()
                                dismiss()
                            } label: {
                                Text("Accept Order")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        LinearGradient(colors: [Color(hex: "2b7fff"), Color(hex: "1a5fd9")], startPoint: .leading, endPoint: .trailing)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .shadow(color: Color(hex: "2b7fff").opacity(0.4), radius: 12, x: 0, y: 6)
                            }
                            .buttonStyle(.plain)
                        }
                    } else if order.status == .preparing || order.status == .ready || order.status == .confirmed || order.status == .accepted {
                        Button {
                            onComplete()
                            dismiss()
                        } label: {
                            Text("Mark as Completed")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(colors: [Color(hex: "22c55e"), Color(hex: "16a34a")], startPoint: .leading, endPoint: .trailing)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .shadow(color: Color(hex: "22c55e").opacity(0.4), radius: 12, x: 0, y: 6)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

#Preview {
    OwnerOrdersScreen()
}
