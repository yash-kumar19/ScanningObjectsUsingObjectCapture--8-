//
//  CartItem.swift
//  GuidedCaptureSample
//
//  Created by Antigravity on 2026-01-30.
//

import Foundation

// MARK: - Cart Item Model

/// Cart item with LOCKED price - never re-fetched from database
/// This prevents price drift if owner updates dish price after customer adds to cart
struct CartItem: Codable, Identifiable {
    let id: String  // Unique cart item ID
    let dishId: String
    let name: String
    let price: Double  // 🔒 LOCKED at add-to-cart, never re-fetched
    let imageURL: String?
    var quantity: Int
    
    var totalPrice: Double {
        price * Double(quantity)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case dishId
        case name
        case price
        case imageURL
        case quantity
    }
    
    // Initialize from Dish model (locks the current price)
    init(dish: Dish, quantity: Int = 1) {
        self.id = UUID().uuidString
        self.dishId = dish.id
        self.name = dish.name
        self.price = dish.price  // LOCK PRICE HERE
        self.imageURL = dish.thumbnail_url
        self.quantity = quantity
    }
    
    // For decoding from UserDefaults
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.dishId = try container.decode(String.self, forKey: .dishId)
        self.name = try container.decode(String.self, forKey: .name)
        self.price = try container.decode(Double.self, forKey: .price)
        self.imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
        self.quantity = try container.decode(Int.self, forKey: .quantity)
    }
}
