//
//  SupabaseManager+Orders.swift
//  GuidedCaptureSample
//
//  Created by Antigravity on 2026-01-30.
//

import Foundation

// MARK: - SupabaseManager Orders Extension

extension SupabaseManager {
    
    // MARK: - Orders (v1 - Polling)
    
    /// Create a new order with items (atomic: pending → received)
    func createOrder(
        restaurantId: String,
        items: [CartItem],
        paymentMethod: PaymentMethod = .cash,
        specialNotes: String? = nil,
        customerName: String?,
        customerPhone: String? = nil
    ) async throws -> Order {
        let token = try await getValidAccessTokenOrRefresh()
        guard let userId = currentUser?.id else {
            throw URLError(.userAuthenticationRequired)
        }
        
        // Calculate totals
        let subtotal = items.reduce(0) { $0 + $1.totalPrice }
        let tax = subtotal * 0.05  // 5% tax
        let total = subtotal + tax
        
        // Generate client-side UUID for idempotency
        let orderId = UUID().uuidString
        
        // STEP 1: Create order with status = 'pending' (safety net)
        var orderPayload: [String: Any] = [
            "id": orderId,
            "customer_id": userId,
            "restaurant_id": restaurantId,
            "status": "pending",   // ← intentionally pending, not visible to owner yet
            "payment_method": paymentMethod.rawValue,
            "subtotal": subtotal,
            "tax": tax,
            "total": total,
            "special_notes": specialNotes as Any,
            "customer_name": customerName as Any,
            "customer_phone": customerPhone as Any
        ]
        
        let orderURL = SupabaseConfig.databaseURL.appendingPathComponent("orders")
        var orderRequest = URLRequest(url: orderURL)
        orderRequest.httpMethod = "POST"
        orderRequest.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        orderRequest.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        orderRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        orderRequest.addValue("return=representation", forHTTPHeaderField: "Prefer")
        orderRequest.httpBody = try JSONSerialization.data(withJSONObject: orderPayload)
        
        let (orderData, orderResponse) = try await URLSession.shared.data(for: orderRequest)
        
        guard let httpOrderResponse = orderResponse as? HTTPURLResponse,
              (200...299).contains(httpOrderResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        // STEP 2: Insert order_items  (if this fails, cleanup the pending order)
        let itemsURL = SupabaseConfig.databaseURL.appendingPathComponent("order_items")
        let itemsPayload = items.map { item in
            [
                "order_id": orderId,
                "dish_id": item.dishId,
                "name": item.name,
                "price": item.price,
                "quantity": item.quantity
            ] as [String: Any]
        }
        
        var itemsRequest = URLRequest(url: itemsURL)
        itemsRequest.httpMethod = "POST"
        itemsRequest.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        itemsRequest.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        itemsRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        itemsRequest.httpBody = try JSONSerialization.data(withJSONObject: itemsPayload)
        
        let (_, itemsResponse) = try await URLSession.shared.data(for: itemsRequest)
        
        guard let httpItemsResponse = itemsResponse as? HTTPURLResponse,
              (200...299).contains(httpItemsResponse.statusCode) else {
            // Items failed → delete the orphaned pending order (best-effort cleanup)
            Task {
                try? await self.deleteOrder(orderId: orderId)
            }
            throw URLError(.badServerResponse)
        }
        
        // STEP 3: Promote order from 'pending' → 'received' (now visible to owner)
        let promoteURL = SupabaseConfig.databaseURL.appendingPathComponent("orders")
            .appending(queryItems: [URLQueryItem(name: "id", value: "eq.\(orderId)")])
        var promoteRequest = URLRequest(url: promoteURL)
        promoteRequest.httpMethod = "PATCH"
        promoteRequest.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        promoteRequest.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        promoteRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        promoteRequest.addValue("return=representation", forHTTPHeaderField: "Prefer")
        promoteRequest.httpBody = try JSONSerialization.data(withJSONObject: ["status": "received"])
        
        let (promoteData, promoteResponse) = try await URLSession.shared.data(for: promoteRequest)
        
        guard let httpPromoteResponse = promoteResponse as? HTTPURLResponse,
              (200...299).contains(httpPromoteResponse.statusCode) else {
            // Promotion failed → still return the order using initial data (best-effort)
            let orders = try JSONDecoder().decode([Order].self, from: orderData)
            guard let order = orders.first else { throw URLError(.cannotDecodeContentData) }
            return order
        }
        
        let orders = try JSONDecoder().decode([Order].self, from: promoteData)
        guard let order = orders.first else {
            throw URLError(.cannotDecodeContentData)
        }
        return order
    }
    
    /// Delete an order by ID (used for cleanup of failed pending orders)
    private func deleteOrder(orderId: String) async throws {
        let token = try await getValidAccessTokenOrRefresh()
        let url = SupabaseConfig.databaseURL.appendingPathComponent("orders")
            .appending(queryItems: [URLQueryItem(name: "id", value: "eq.\(orderId)")])
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        _ = try? await URLSession.shared.data(for: request)
    }
    
    /// Fetch customer's orders
    func fetchCustomerOrders() async throws -> [Order] {
        let token = try await getValidAccessTokenOrRefresh()
        guard let userId = currentUser?.id else {
            throw URLError(.userAuthenticationRequired)
        }
        
        let url = SupabaseConfig.databaseURL.appendingPathComponent("orders")
            .appending(queryItems: [
                URLQueryItem(name: "customer_id", value: "eq.\(userId)"),
                URLQueryItem(name: "order", value: "created_at.desc"),
                URLQueryItem(name: "select", value: "*")
            ])
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode([Order].self, from: data)
    }
    
    /// Fetch restaurant's orders (for owners) — includes order_items joined
    func fetchRestaurantOrders(restaurantId: String, startDate: Date? = nil) async throws -> [Order] {
        let token = try await getValidAccessTokenOrRefresh()
        
        var queryItems = [
            URLQueryItem(name: "restaurant_id", value: "eq.\(restaurantId)"),
            URLQueryItem(name: "order", value: "created_at.desc"),
            URLQueryItem(name: "select", value: "*,items:order_items(*)")
        ]
        
        if let startDate = startDate {
            let formatter = ISO8601DateFormatter()
            let dateString = formatter.string(from: startDate)
            queryItems.append(URLQueryItem(name: "created_at", value: "gte.\(dateString)"))
        }
        
        let baseURL = SupabaseConfig.databaseURL.appendingPathComponent("orders")
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true)
        components?.queryItems = queryItems
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            if let httpResponse = response as? HTTPURLResponse {
                let body = String(data: data, encoding: .utf8) ?? ""
                print("❌ fetchRestaurantOrders failed with status \(httpResponse.statusCode): \(body)")
            }
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode([Order].self, from: data)
    }
    
    /// Fetch single order by ID
    func fetchOrderById(_ orderId: String) async throws -> Order {
        let token = try await getValidAccessTokenOrRefresh()
        
        let url = SupabaseConfig.databaseURL.appendingPathComponent("orders")
            .appending(queryItems: [
                URLQueryItem(name: "id", value: "eq.\(orderId)"),
                URLQueryItem(name: "select", value: "*")
            ])
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let orders = try JSONDecoder().decode([Order].self, from: data)
        guard let order = orders.first else {
            throw URLError(.cannotDecodeContentData)
        }
        
        return order
    }
    
    /// Update order status with state machine validation
    func updateOrderStatus(orderId: String, newStatus: OrderStatus) async throws -> Order {
        let token = try await getValidAccessTokenOrRefresh()
        
        // Fetch current order to validate transition
        let currentOrder = try await fetchOrderById(orderId)
        
        // Validate state transition
        guard validateStatusTransition(from: currentOrder.status, to: newStatus) else {
            throw OrderStatusError.invalidTransition(from: currentOrder.status, to: newStatus)
        }
        
        // Update order
        let url = SupabaseConfig.databaseURL.appendingPathComponent("orders")
            .appending(queryItems: [
                URLQueryItem(name: "id", value: "eq.\(orderId)")
            ])
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("return=representation", forHTTPHeaderField: "Prefer")
        
        let body = ["status": newStatus.rawValue]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let orders = try JSONDecoder().decode([Order].self, from: data)
        guard let updatedOrder = orders.first else {
            throw URLError(.cannotDecodeContentData)
        }
        
        return updatedOrder
    }
    
    /// Validate order status transitions (state machine)
    func validateStatusTransition(from currentStatus: OrderStatus, to newStatus: OrderStatus) -> Bool {
        switch (currentStatus, newStatus) {
        // Received can go to Preparing or Cancelled
        case (.received, .preparing), (.received, .cancelled):
            return true
            
        // Preparing can only go to Ready
        case (.preparing, .ready):
            return true
            
        // Ready can only go to Completed
        case (.ready, .completed):
            return true
            
        // Terminal states (no transitions allowed)
        case (.completed, _), (.cancelled, _):
            return false
            
        // All other transitions are invalid
        default:
            return false
        }
    }
}

// MARK: - Order Polling Manager

class OrderPollingManager: ObservableObject {
    private var timer: Timer?
    private var isActive = false
    
    /// Start polling with given interval
    func startPolling(interval: TimeInterval, action: @escaping () async -> Void) {
        stopPolling()
        isActive = true
        
        // Execute immediately
        Task { await action() }
        
        // Then poll on interval
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self, self.isActive else { return }
            Task { await action() }
        }
    }
    
    /// Stop polling
    func stopPolling() {
        timer?.invalidate()
        timer = nil
        isActive = false
    }
    
    deinit {
        stopPolling()
    }
}

// MARK: - Order Status Error

enum OrderStatusError: LocalizedError {
    case invalidTransition(from: OrderStatus, to: OrderStatus)
    
    var errorDescription: String? {
        switch self {
        case .invalidTransition(let from, let to):
            return "Cannot transition from \(from.displayName) to \(to.displayName)"
        }
    }
}
