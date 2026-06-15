//
//  CartScreen.swift
//  GuidedCaptureSample
//
//  Created by Antigravity on 2026-01-30.
//

import SwiftUI

struct CartScreen: View {
    @ObservedObject var cartManager = CartManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    var onCheckout: () -> Void
    var hasActiveOrder: Bool
    var onViewOrders: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Color.clear.frame(width: 40, height: 40)
                
                Spacer()
                
                Text("Cart")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Persistent Orders button
                Button(action: onViewOrders) {
                    HStack(spacing: 4) {
                        Image(systemName: "list.clipboard")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Orders")
                            .font(.system(size: 12, weight: .semibold))
                        
                        if hasActiveOrder {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 6, height: 6)
                        }
                    }
                    .foregroundColor(Color(hex: "3B82F6"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(hex: "3B82F6").opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color(hex: "3B82F6").opacity(0.3), lineWidth: 1))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Color(hex: "1E293B")
                    .ignoresSafeArea(.container, edges: .top)
            )
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.white.opacity(0.08)),
                alignment: .bottom
            )
            
            if cartManager.isEmpty {
                // Empty State — positioned naturally near the top
                VStack(spacing: 20) {
                    Image(systemName: "cart")
                        .font(.system(size: 60))
                        .foregroundColor(Color.white.opacity(0.3))
                    
                    Text("Your cart is empty")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Add items from the menu to get started")
                        .font(.system(size: 15))
                        .foregroundColor(Color.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)
                .padding(.top, 80)
                
                Spacer()  // Push remaining space below
            } else {
                // Cart Items + Bottom Summary
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(cartManager.items) { item in
                            CartItemRow(
                                item: item,
                                onIncrement: {
                                    cartManager.updateQuantity(itemId: item.id, quantity: item.quantity + 1)
                                },
                                onDecrement: {
                                    if item.quantity > 1 {
                                        cartManager.updateQuantity(itemId: item.id, quantity: item.quantity - 1)
                                    } else {
                                        withAnimation {
                                            cartManager.removeItem(item.id)
                                        }
                                    }
                                },
                                onDelete: {
                                    withAnimation {
                                        cartManager.removeItem(item.id)
                                    }
                                }
                            )
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 16)
                }
                
                // Order Summary & Checkout — pinned at the bottom
                VStack(spacing: 0) {
                    // Subtle top fade
                    LinearGradient(
                        colors: [Theme.background.opacity(0), Theme.background],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 20)
                    
                    // Summary Card
                    VStack(spacing: 12) {
                        HStack {
                            Text("Subtotal")
                                .font(.system(size: 15))
                                .foregroundColor(Color.white.opacity(0.7))
                            Spacer()
                            Text(String(format: "$%.2f", cartManager.subtotal))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                        }
                        
                        HStack {
                            Text("Tax (5%)")
                                .font(.system(size: 15))
                                .foregroundColor(Color.white.opacity(0.7))
                            Spacer()
                            Text(String(format: "$%.2f", cartManager.tax))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.vertical, 4)
                        
                        HStack {
                            Text("Total")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            Text(String(format: "$%.2f", cartManager.total))
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color(hex: "3B82F6"))
                        }
                    }
                    .padding(20)
                    .background(Color(hex: "1E293B"))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                    
                    // Checkout Button
                    Button(action: onCheckout) {
                        HStack {
                            Text("Place Order")
                                .font(.system(size: 17, weight: .bold))
                            
                            Spacer()
                            
                            Text(String(format: "$%.2f", cartManager.total))
                                .font(.system(size: 17, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(hex: "3B82F6"),
                                    Color(hex: "2563EB")
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: Color(hex: "3B82F6").opacity(0.4), radius: 12, x: 0, y: 6)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 100) // Clear space for the floating tab bar
                }
                .background(Theme.background)
            }
        }
        .background(Theme.background.ignoresSafeArea())
    }
}

// MARK: - Cart Item Row

struct CartItemRow: View {
    let item: CartItem
    let onIncrement: () -> Void
    let onDecrement: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Image
            AsyncImage(url: URL(string: item.imageURL ?? "")) { phase in
                switch phase {
                case .empty:
                    Rectangle().fill(Color.white.opacity(0.05))
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                case .failure:
                    Rectangle().fill(Color.white.opacity(0.05))
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.white.opacity(0.3))
                        )
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 70, height: 70)
            .cornerRadius(12)
            .clipped()
            
            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text(item.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(String(format: "$%.2f", item.price))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "3B82F6"))
                
                Text("Total: \(String(format: "$%.2f", item.totalPrice))")
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.6))
            }
            
            Spacer()
            
            // Quantity Controls
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    // Decrement
                    Button(action: onDecrement) {
                        Image(systemName: item.quantity > 1 ? "minus" : "trash")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color(hex: "1E293B"))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    }
                    
                    // Quantity
                    Text("\(item.quantity)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 30)
                    
                    // Increment
                    Button(action: onIncrement) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color(hex: "3B82F6"))
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(12)
        .background(Color(hex: "1E293B"))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

#Preview {
    CartScreen(onCheckout: {}, hasActiveOrder: false, onViewOrders: {})
}

// MARK: - Orders Details Screen

struct OrdersDetailsScreen: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var historyManager = OrderHistoryManager.shared
    
    @State private var orders: [Order] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var selectedTab = 0 // 0 = Active, 1 = History
    @State private var selectedOrderId: String? = nil
    
    private var safeAreaTopInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.top ?? 44
    }
    
    var activeOrders: [Order] {
        orders.filter { $0.status != .completed && $0.status != .cancelled }
    }
    
    struct GroupedOrders: Identifiable {
        let id = UUID()
        let dateHeader: String
        let orders: [Order]
    }
    
    var groupedHistoryOrders: [GroupedOrders] {
        let history = orders.filter { $0.status == .completed || $0.status == .cancelled }
        let dictionary = Dictionary(grouping: history) { formatDateHeader($0.created_at) }
        
        return dictionary.map { key, value in
            GroupedOrders(dateHeader: key, orders: value.sorted { $0.created_at > $1.created_at })
        }.sorted { g1, g2 in
            guard let o1 = g1.orders.first, let o2 = g2.orders.first else { return false }
            return o1.created_at > o2.created_at
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.05))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                }
                
                Spacer()
                
                Text("My Orders")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Color.clear.frame(width: 40, height: 40)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Color(hex: "1E293B")
                    .ignoresSafeArea(.container, edges: .top)
            )
            .overlay(
                Rectangle().frame(height: 1).foregroundColor(Color.white.opacity(0.08)),
                alignment: .bottom
            )
            
            // Tab Selector
            HStack(spacing: 0) {
                tabButton(title: "Active Orders", index: 0)
                tabButton(title: "Order History", index: 1)
            }
            .background(Color(hex: "1E293B").opacity(0.5))
            .padding(.top, 0)
            
            // Content
            ZStack {
                Theme.background.ignoresSafeArea()
                
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                        Text("Loading orders...")
                            .font(.system(size: 15))
                            .foregroundColor(Color.white.opacity(0.6))
                    }
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button(action: {
                            Task {
                                await fetchAllOrders()
                            }
                        }) {
                            Text("Retry")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color(hex: "3B82F6"))
                                .cornerRadius(12)
                        }
                        .padding(.top, 8)
                    }
                } else if historyManager.orderIds.isEmpty {
                    emptyStateView(icon: "doc.plaintext", message: "You haven't placed any orders yet")
                } else {
                    if selectedTab == 0 {
                        // Active Orders
                        if activeOrders.isEmpty {
                            emptyStateView(icon: "bell.slash", message: "No active orders right now")
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    ForEach(activeOrders) { order in
                                        orderRow(order: order)
                                    }
                                }
                                .padding(20)
                            }
                        }
                    } else {
                        // Order History
                        if groupedHistoryOrders.isEmpty {
                            emptyStateView(icon: "clock.arrow.circlepath", message: "No past orders in your history")
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 20) {
                                    ForEach(groupedHistoryOrders) { group in
                                        VStack(alignment: .leading, spacing: 10) {
                                            Text(group.dateHeader)
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(Color.white.opacity(0.5))
                                                .padding(.horizontal, 4)
                                            
                                            ForEach(group.orders) { order in
                                                orderRow(order: order)
                                            }
                                        }
                                    }
                                }
                                .padding(20)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.background.ignoresSafeArea())
        .onAppear {
            Task {
                await fetchAllOrders()
            }
        }
        .fullScreenCover(item: Binding(
            get: { selectedOrderId.map { OrderIdWrapper(id: $0) } },
            set: { if $0 == nil { selectedOrderId = nil } }
        )) { wrapper in
            CustomerOrderStatusScreen(orderId: wrapper.id)
        }
    }
    
    // MARK: - Subviews
    
    private func tabButton(title: String, index: Int) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = index
            }
        }) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 15, weight: selectedTab == index ? .bold : .medium))
                    .foregroundColor(selectedTab == index ? .white : Color.white.opacity(0.5))
                    .padding(.top, 14)
                
                // Underline indicator
                Rectangle()
                    .fill(selectedTab == index ? Color(hex: "3B82F6") : Color.clear)
                    .frame(height: 3)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
    
    private func emptyStateView(icon: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(Color.white.opacity(0.2))
            
            Text(message)
                .font(.system(size: 16))
                .foregroundColor(Color.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxHeight: .infinity)
    }
    
    private func orderRow(order: Order) -> some View {
        Button(action: {
            selectedOrderId = order.id
        }) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(order.displayOrderNumber)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(formatOrderTime(order.created_at))
                            .font(.system(size: 13))
                            .foregroundColor(Color.white.opacity(0.4))
                    }
                    
                    Text("\(order.items?.count ?? 0) items • \(String(format: "$%.2f", order.total))")
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.7))
                }
                
                Spacer()
                
                // Status Badge
                Text(order.status.displayName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(statusColor(order.status).opacity(0.15))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(statusColor(order.status).opacity(0.4), lineWidth: 1)
                    )
            }
            .padding(16)
            .background(Color(hex: "1E293B"))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Helper Methods
    
    private func statusColor(_ status: OrderStatus) -> Color {
        switch status {
        case .pending:
            return Color(hex: "6B7280")
        case .received, .placed:
            return Color(hex: "3B82F6")
        case .confirmed, .accepted:
            return Color(hex: "3B82F6")
        case .preparing:
            return Color(hex: "F59E0B")
        case .ready:
            return Color(hex: "10B981")
        case .completed:
            return Color(hex: "10B981")
        case .cancelled:
            return Color(hex: "EF4444")
        }
    }
    
    func fetchAllOrders() async {
        let ids = historyManager.orderIds
        guard !ids.isEmpty else {
            await MainActor.run {
                self.orders = []
                self.isLoading = false
            }
            return
        }
        
        await MainActor.run { self.isLoading = true; self.errorMessage = nil }
        
        do {
            var fetchedOrders: [Order] = []
            try await withThrowingTaskGroup(of: Order?.self) { group in
                for id in ids {
                    group.addTask {
                        do {
                            return try await SupabaseManager.shared.fetchOrderById(id)
                        } catch {
                            print("Error fetching order \(id): \(error)")
                            return nil
                        }
                    }
                }
                
                for try await orderOpt in group {
                    if let order = orderOpt {
                        fetchedOrders.append(order)
                    }
                }
            }
            
            // Sort by created_at descending
            fetchedOrders.sort { o1, o2 in
                o1.created_at > o2.created_at
            }
            
            await MainActor.run {
                self.orders = fetchedOrders
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func formatDateHeader(_ dateString: String) -> String {
        let inputFormatter = ISO8601DateFormatter()
        inputFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var date = inputFormatter.date(from: dateString)
        if date == nil {
            let altFormatter = ISO8601DateFormatter()
            date = altFormatter.date(from: dateString)
        }
        
        guard let date = date else { return "Past Orders" }
        
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let outputFormatter = DateFormatter()
            outputFormatter.dateStyle = .medium
            outputFormatter.timeStyle = .none
            return outputFormatter.string(from: date)
        }
    }
    
    private func formatOrderTime(_ dateString: String) -> String {
        let inputFormatter = ISO8601DateFormatter()
        inputFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var date = inputFormatter.date(from: dateString)
        if date == nil {
            let altFormatter = ISO8601DateFormatter()
            date = altFormatter.date(from: dateString)
        }
        
        guard let date = date else { return "" }
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateStyle = .none
        outputFormatter.timeStyle = .short
        return outputFormatter.string(from: date)
    }
}

