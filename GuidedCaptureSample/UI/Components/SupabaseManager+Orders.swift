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
    
    /// Create a new order with items via the secure SECURITY DEFINER RPC.
    /// Auth token is optional — the RPC works with the anon key alone for unauthenticated customers.
    func createOrder(
        restaurantId: String,
        items: [CartItem],
        paymentMethod: PaymentMethod = .cash,
        specialNotes: String? = nil,
        customerName: String?,
        customerPhone: String? = nil
    ) async throws -> Order {
        // Optional auth — don't throw if customer is not logged in
        let optionalToken: String? = try? await getValidAccessTokenOrRefresh()
        
        let itemsPayload: [[String: Any]] = items.map { item in
            ["dish_id": item.dishId, "quantity": item.quantity]
        }
        
        let clientToken = "order_\(UUID().uuidString)"
        
        // Build payload — ALL parameters must be present for PostgREST to
        // match the function signature. Use empty strings for nil optionals.
        let rpcPayload: [String: Any] = [
            "p_restaurant_id": restaurantId,
            "p_customer_name": customerName ?? "Customer",
            "p_customer_phone": customerPhone ?? "",
            "p_table_number": "iOS",
            "p_items": itemsPayload,
            "p_client_token": clientToken,
            "p_special_instructions": specialNotes ?? ""
        ]
        
        let rpcURL = SupabaseConfig.databaseURL.appendingPathComponent("rpc/create_order_with_items")
        var rpcRequest = URLRequest(url: rpcURL, timeoutInterval: 20)
        rpcRequest.httpMethod = "POST"
        rpcRequest.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        rpcRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        // Use user JWT when available; fall back to anon bearer so unauthenticated customers can order
        let bearerToken = optionalToken ?? SupabaseConfig.anonKey
        rpcRequest.addValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        rpcRequest.httpBody = try JSONSerialization.data(withJSONObject: rpcPayload)
        
        print("🚀 RPC create_order_with_items — items: \(itemsPayload.count), auth: \(optionalToken != nil ? "jwt" : "anon")")
        
        let (data, response) = try await URLSession.shared.data(for: rpcRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "RPC Failed"
            print("❌ create_order_with_items [\(httpResponse.statusCode)]: \(errorMsg)")
            throw SupabaseAPIError(statusCode: httpResponse.statusCode, message: errorMsg)
        }
        
        let responseString = String(data: data, encoding: .utf8) ?? ""
        print("✅ RPC Result: \(responseString)")
        
        // RPC returns a plain UUID (may be JSON-quoted)
        let orderId = responseString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        
        guard !orderId.isEmpty, orderId.count >= 8 else {
            let msg = "Unexpected RPC response: \(responseString)"
            print("❌ \(msg)")
            throw SupabaseAPIError(statusCode: 0, message: msg)
        }
        
        // Build the Order locally from data we already have.
        // We deliberately do NOT call fetchOrderById here because customers
        // have no SELECT RLS policy on the orders table — only the restaurant
        // owner can SELECT their own orders.  All the info the success screen
        // needs (id, totals, customer details) is already in scope.
        let subtotal = items.reduce(0.0) { $0 + $1.totalPrice }
        let tax      = subtotal * 0.05
        let total    = subtotal + tax
        return Order(
            id: orderId,
            restaurantId: restaurantId,
            status: .received,
            paymentMethod: paymentMethod,
            subtotal: subtotal,
            tax: tax,
            total: total,
            specialNotes: specialNotes,
            customerName: customerName,
            customerPhone: customerPhone
        )
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
            if let httpResponse = response as? HTTPURLResponse {
                let errorBody = String(data: data, encoding: .utf8) ?? "<no body>"
                print("❌ fetchCustomerOrders failed with status \(httpResponse.statusCode): \(errorBody)")
            }
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode([Order].self, from: data)
    }
    
    /// Fetch restaurant's orders (for owners) — includes order_items joined
    func fetchRestaurantOrders(restaurantId: String, startDate: Date? = nil, limit: Int? = nil, offset: Int? = nil) async throws -> [Order] {
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
        
        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: "\(limit)"))
        }
        
        if let offset = offset {
            queryItems.append(URLQueryItem(name: "offset", value: "\(offset)"))
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
    
    /// Fetch dashboard metrics strictly optimized
    func fetchDashboardOrders(restaurantId: String, startDate: Date) async throws -> [Order] {
        let token = try await getValidAccessTokenOrRefresh()
        
        let formatter = ISO8601DateFormatter()
        let dateString = formatter.string(from: startDate)
        
        let queryItems = [
            URLQueryItem(name: "restaurant_id", value: "eq.\(restaurantId)"),
            URLQueryItem(name: "created_at", value: "gte.\(dateString)"),
            URLQueryItem(name: "select", value: "id,status,total,created_at")
        ]
        
        let baseURL = SupabaseConfig.databaseURL.appendingPathComponent("orders")
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true)
        components?.queryItems = queryItems
        guard let url = components?.url else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode([Order].self, from: data)
    }
    
    /// Fetch strictly delta updates since last poll
    func fetchUpdatedOrders(restaurantId: String, since date: Date) async throws -> [Order] {
        let token = try await getValidAccessTokenOrRefresh()
        
        let formatter = ISO8601DateFormatter()
        let dateString = formatter.string(from: date)
        
        let queryItems = [
            URLQueryItem(name: "restaurant_id", value: "eq.\(restaurantId)"),
            URLQueryItem(name: "updated_at", value: "gt.\(dateString)"),
            URLQueryItem(name: "select", value: "*,items:order_items(*)")
        ]
        
        let baseURL = SupabaseConfig.databaseURL.appendingPathComponent("orders")
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true)
        components?.queryItems = queryItems
        guard let url = components?.url else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode([Order].self, from: data)
    }
    
    /// Fetch single order by ID (works for customers with anon key — relies on read RPC or direct select)
    func fetchOrderById(_ orderId: String) async throws -> Order {
        // Auth is optional — use anon key fallback so customers don’t need to be logged in
        let optionalToken: String? = try? await getValidAccessTokenOrRefresh()
        let bearer = optionalToken ?? SupabaseConfig.anonKey
        
        let url = SupabaseConfig.databaseURL.appendingPathComponent("rpc/get_customer_order_by_id")
        let payload: [String: Any] = ["p_order_id": orderId]
        
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.addValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            if let httpResponse = response as? HTTPURLResponse {
                let errorBody = String(data: data, encoding: .utf8) ?? "<no body>"
                print("❌ fetchOrderById RPC [\(httpResponse.statusCode)]: \(errorBody)")
            }
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(Order.self, from: data)
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
            if let httpResponse = response as? HTTPURLResponse {
                let errorBody = String(data: data, encoding: .utf8) ?? "<no body>"
                print("❌ updateOrderStatus failed with status \(httpResponse.statusCode): \(errorBody)")
            }
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
        // Initial states: received or placed can transition to confirmed, preparing, completed, or cancelled
        case (.received, .confirmed), (.received, .preparing), (.received, .completed), (.received, .cancelled),
             (.placed, .confirmed), (.placed, .preparing), (.placed, .completed), (.placed, .cancelled):
            return true
            
        // Confirmed / accepted can transition to preparing, completed, or cancelled
        case (.confirmed, .preparing), (.confirmed, .completed), (.confirmed, .cancelled),
             (.accepted, .preparing), (.accepted, .completed), (.accepted, .cancelled):
            return true
            
        // Preparing can transition to ready, completed, or cancelled
        case (.preparing, .ready), (.preparing, .completed), (.preparing, .cancelled):
            return true
            
        // Ready can transition to completed or cancelled
        case (.ready, .completed), (.ready, .cancelled):
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
