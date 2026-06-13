//
//  CustomerOrderStatusScreen.swift
//  GuidedCaptureSample
//
//  Created by Antigravity on 2026-01-30.
//

import SwiftUI

struct CustomerOrderStatusScreen: View {
    @Environment(\.presentationMode) var presentationMode
    
    let orderId: String
    
    @State private var order: Order?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @StateObject private var pollingManager = OrderPollingManager()
    
    // Safe area helpers
    private var safeAreaTopInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.top ?? 44
    }

    var body: some View {
        Group {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.05))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                    
                    Spacer()
                    
                    Text("Order Status")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Color.clear.frame(width: 40)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .padding(.top, safeAreaTopInset)
                .background(Color(hex: "1E293B"))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color.white.opacity(0.08)),
                    alignment: .bottom
                )
                
                if isLoading {
                    VStack(spacing: 20) {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Loading order...")
                            .foregroundColor(Color.white.opacity(0.7))
                        Spacer()
                    }
                } else if let error = errorMessage {
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        Text("Error loading order")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(Color.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .padding(40)
                } else if let order = order {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Order Number Card
                            VStack(spacing: 12) {
                                Text("Order Number")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.white.opacity(0.7))
                                
                                Text(order.displayOrderNumber)
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(Color(hex: "3B82F6"))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            .background(Color(hex: "1E293B"))
                            .cornerRadius(16)
                            
                            // Status Progress
                            OrderStatusProgress(currentStatus: order.status)
                            
                            // Status Info Card
                            HStack(spacing: 12) {
                                Image(systemName: order.status.iconName)
                                    .font(.system(size: 24))
                                    .foregroundColor(statusColor(order.status))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(order.status.displayName)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text(statusMessage(order.status))
                                        .font(.system(size: 14))
                                        .foregroundColor(Color.white.opacity(0.7))
                                }
                                
                                Spacer()
                            }
                            .padding(20)
                            .background(Color(hex: "1E293B"))
                            .cornerRadius(16)
                            
                            // Manual Update Info
                            if order.status != .completed && order.status != .cancelled {
                                HStack(spacing: 12) {
                                    Image(systemName: "info.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(Color(hex: "3B82F6"))
                                    
                                    Text("Order status is updated manually by restaurant staff. This screen refreshes automatically every 5 seconds.")
                                        .font(.system(size: 13))
                                        .foregroundColor(Color.white.opacity(0.7))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(16)
                                .background(Color(hex: "1E293B"))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(hex: "3B82F6").opacity(0.3), lineWidth: 1)
                                )
                            }
                            
                            // Order Details
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Order Details")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                
                                if let customerName = order.customer_name {
                                    DetailRow(label: "Name", value: customerName)
                                }
                                
                                DetailRow(label: "Payment", value: order.payment_method.displayName)
                                
                                if let notes = order.special_notes, !notes.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Special Instructions")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(Color.white.opacity(0.7))
                                        
                                        Text(notes)
                                            .font(.system(size: 15))
                                            .foregroundColor(.white)
                                            .padding(12)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color(hex: "0F172A"))
                                            .cornerRadius(8)
                                    }
                                }
                                
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                    .padding(.vertical, 4)
                                
                                VStack(spacing: 8) {
                                    DetailRow(label: "Subtotal", value: String(format: "$%.2f", order.subtotal))
                                    DetailRow(label: "Tax", value: String(format: "$%.2f", order.tax))
                                    
                                    HStack {
                                        Text("Total")
                                            .font(.system(size: 17, weight: .bold))
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text(String(format: "$%.2f", order.total))
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(Color(hex: "3B82F6"))
                                    }
                                }
                            }
                            .padding(20)
                            .background(Color(hex: "1E293B"))
                            .cornerRadius(16)
                        }
                        .padding(20)
                        .padding(.bottom, 40)
                    }
                    .refreshable {
                        await loadOrder()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.background)
        .ignoresSafeArea(.all)
        .task {
            await loadOrder()
            pollingManager.startPolling(interval: 5.0) {
                await loadOrder()
            }
        }
        .onDisappear {
            pollingManager.stopPolling()
        }
    }
    
    // MARK: - Helpers
    
    private func loadOrder() async {
        do {
            let fetchedOrder = try await SupabaseManager.shared.fetchOrderById(orderId)
            await MainActor.run {
                self.order = fetchedOrder
                self.isLoading = false
                self.errorMessage = nil
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func statusColor(_ status: OrderStatus) -> Color {
        switch status {
        case .pending:
            return Color(hex: "6B7280")  // Gray — not visible to customer normally
        case .received, .placed:
            return Color(hex: "3B82F6")  // Blue
        case .confirmed, .accepted:
            return Color(hex: "3B82F6")  // Blue / Confirmed status color
        case .preparing:
            return Color(hex: "F59E0B")  // Orange
        case .ready:
            return Color(hex: "10B981")  // Green
        case .completed:
            return Color(hex: "6B7280")  // Gray
        case .cancelled:
            return Color(hex: "EF4444")  // Red
        }
    }
    
    private func statusMessage(_ status: OrderStatus) -> String {
        switch status {
        case .pending:
            return "Placing your order..."
        case .received, .placed:
            return "Your order has been received and is waiting to be prepared"
        case .confirmed, .accepted:
            return "Your order has been confirmed by the restaurant"
        case .preparing:
            return "Your food is being prepared"
        case .ready:
            return "Your order is ready for pickup!"
        case .completed:
            return "Order completed. Thank you!"
        case .cancelled:
            return "This order was cancelled"
        }
    }
}

// MARK: - Order Status Progress

struct OrderStatusProgress: View {
    let currentStatus: OrderStatus
    
    private let statuses: [OrderStatus] = [.received, .confirmed, .completed]
    
    private func normalizedStatus(_ status: OrderStatus) -> OrderStatus {
        switch status {
        case .pending:
            return .received
        case .received, .placed:
            return .received
        case .confirmed, .accepted, .preparing, .ready:
            return .confirmed
        case .completed:
            return .completed
        case .cancelled:
            return .received
        }
    }
    
    private func isActive(_ status: OrderStatus) -> Bool {
        if currentStatus == .cancelled {
            return false
        }
        let normCurrent = normalizedStatus(currentStatus)
        guard let currentIndex = statuses.firstIndex(of: normCurrent),
              let statusIndex = statuses.firstIndex(of: status) else {
            return false
        }
        return statusIndex <= currentIndex
    }
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 0) {
                ForEach(Array(statuses.enumerated()), id: \.offset) { index, status in
                    VStack(spacing: 8) {
                        // Circle
                        ZStack {
                            Circle()
                                .fill(isActive(status) ? Color(hex: "3B82F6") : Color(hex: "334155"))
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: status.iconName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        
                        // Label
                        Text(status.displayName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(isActive(status) ? .white : Color.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .frame(width: 70)
                    }
                    
                    if index < statuses.count - 1 {
                        // Connector Line
                        Rectangle()
                            .fill(isActive(statuses[index + 1]) ? Color(hex: "3B82F6") : Color(hex: "334155"))
                            .frame(height: 2)
                            .offset(y: -12)
                    }
                }
            }
        }
        .padding(20)
        .background(Color(hex: "1E293B"))
        .cornerRadius(16)
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(Color.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
        }
    }
}

#Preview {
    CustomerOrderStatusScreen(orderId: "test-order-id")
}
