//
//  Order.swift
//  GuidedCaptureSample
//
//  Created by Antigravity on 2026-01-30.
//

import Foundation

// MARK: - Order Model

struct Order: Decodable, Identifiable {
    let id: String  // UUID from Supabase
    let created_at: String  // ISO 8601 timestamp from Supabase
    let updated_at: String? // Optional ISO 8601 timestamp
    let customer_id: String
    let restaurant_id: String
    let restaurant_name: String?  // SNAPSHOT for display (not live reference)
    let status: OrderStatus
    let payment_method: PaymentMethod
    let subtotal: Double
    let tax: Double
    let total: Double
    let special_notes: String?
    let customer_name: String?
    let customer_phone: String?   // E.164 format e.g. +919876543210
    let items: [OrderItem]?
    
    // Display order number using UUID suffix (no global SERIAL needed)
    var displayOrderNumber: String {
        "#\(id.suffix(4).uppercased())"
    }
    
    // Local memberwise init — used after a successful RPC call so we never
    // need a DB SELECT (customers have no SELECT RLS policy on orders table).
    init(
        id: String,
        restaurantId: String,
        status: OrderStatus,
        paymentMethod: PaymentMethod,
        subtotal: Double,
        tax: Double,
        total: Double,
        specialNotes: String? = nil,
        customerName: String? = nil,
        customerPhone: String? = nil,
        items: [OrderItem] = [],
        updatedAt: String? = nil
    ) {
        self.id            = id
        self.created_at    = ISO8601DateFormatter().string(from: Date())
        self.updated_at    = updatedAt
        self.customer_id   = "temp"
        self.restaurant_id = restaurantId
        self.restaurant_name = nil
        self.status        = status
        self.payment_method = paymentMethod
        self.subtotal      = subtotal
        self.tax           = tax
        self.total         = total
        self.special_notes = specialNotes
        self.customer_name = customerName
        self.customer_phone = customerPhone
        self.items         = items
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case created_at
        case updated_at
        case customer_id
        case restaurant_id
        case restaurant_name
        case status
        case payment_method
        case subtotal
        case tax
        case total
        case total_amount = "total_amount"
        case special_notes
        case special_instructions = "special_instructions"
        case customer_name
        case customer_phone
        case items
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.created_at = try container.decode(String.self, forKey: .created_at)
        
        // Handle customer_id (not present in orders table v2, fallback to empty)
        self.customer_id = (try? container.decode(String.self, forKey: .customer_id)) ?? ""
        
        self.restaurant_id = try container.decode(String.self, forKey: .restaurant_id)
        self.restaurant_name = try container.decodeIfPresent(String.self, forKey: .restaurant_name)
        self.status = try container.decode(OrderStatus.self, forKey: .status)
        self.payment_method = (try? container.decode(PaymentMethod.self, forKey: .payment_method)) ?? .cash
        
        // Decode total/total_amount
        if let totalVal = try? container.decode(Double.self, forKey: .total) {
            self.total = totalVal
        } else if let totalAmount = try? container.decode(Double.self, forKey: .total_amount) {
            self.total = totalAmount
        } else {
            self.total = 0.0
        }
        
        // Decode subtotal and tax (not in DB, compute from total)
        self.subtotal = (try? container.decode(Double.self, forKey: .subtotal)) ?? (self.total / 1.05)
        self.tax = (try? container.decode(Double.self, forKey: .tax)) ?? (self.total - self.subtotal)
        
        // Decode special_notes/special_instructions
        self.special_notes = (try? container.decodeIfPresent(String.self, forKey: .special_notes)) ?? (try? container.decodeIfPresent(String.self, forKey: .special_instructions))
        
        self.customer_name = try container.decodeIfPresent(String.self, forKey: .customer_name)
        self.customer_phone = try container.decodeIfPresent(String.self, forKey: .customer_phone)
        self.updated_at = try container.decodeIfPresent(String.self, forKey: .updated_at)
        self.items = try container.decodeIfPresent([OrderItem].self, forKey: .items)
    }
}

// MARK: - Order Item Model

struct OrderItem: Codable, Identifiable {
    let id: String
    let order_id: String
    let dish_id: String
    let name: String
    let price: Double  // Locked price at time of order
    let quantity: Int
    
    var totalPrice: Double {
        price * Double(quantity)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case order_id
        case dish_id
        case name = "dish_name"
        case price
        case quantity
    }
}

// MARK: - Order Status Enum

enum OrderStatus: String, Codable {
    case pending = "pending"      // Created but items not yet inserted (safety net)
    case received = "received"   // Order placed by customer — visible to owner
    case placed = "placed"       // Database v2: initial order status
    case confirmed = "confirmed" // Database v2: order accepted by owner
    case accepted = "accepted"   // Database v2: order accepted (alternative)
    case preparing = "preparing"  // Kitchen started preparing
    case ready = "ready"         // Food is ready for pickup
    case completed = "completed"  // Order delivered/picked up
    case cancelled = "cancelled"  // Rejected by owner (only from 'received')
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .received, .placed: return "Received"
        case .confirmed, .accepted: return "Confirmed"
        case .preparing: return "Preparing"
        case .ready: return "Ready"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
    
    var iconName: String {
        switch self {
        case .pending: return "clock"
        case .received, .placed: return "bell.fill"
        case .confirmed, .accepted: return "checkmark.circle.fill"
        case .preparing: return "flame.fill"
        case .ready: return "checkmark.circle.fill"
        case .completed: return "checkmark.seal.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .pending: return "gray"
        case .received, .placed: return "blue"
        case .confirmed, .accepted: return "blue"
        case .preparing: return "orange"
        case .ready: return "green"
        case .completed: return "gray"
        case .cancelled: return "red"
        }
    }
}

// MARK: - Payment Method Enum

enum PaymentMethod: String, Codable {
    case cash = "cash"  // v1: Cash only at restaurant
    // v2: Add card, online payment gateways
    
    var displayName: String {
        switch self {
        case .cash: return "Cash at Restaurant"
        }
    }
    
    var iconName: String {
        switch self {
        case .cash: return "banknote.fill"
        }
    }
}


