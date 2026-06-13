//
//  CartManager.swift
//  GuidedCaptureSample
//
//  Created by Antigravity on 2026-01-30.
//

import Foundation
import SwiftUI

// MARK: - Cart Manager

/// Observable cart state manager with UserDefaults persistence
/// Automatically saves cart on every modification and restores on launch
class CartManager: ObservableObject {
    static let shared = CartManager()
    
    @Published var items: [CartItem] = [] {
        didSet {
            saveCart()  // Auto-save on every change
        }
    }
    
    @Published var restaurantId: String? {
        didSet {
            saveRestaurantId()
        }
    }
    
    @Published var restaurantName: String? {
        didSet {
            saveRestaurantName()
        }
    }
    
    // UserDefaults keys
    private let cartItemsKey = "cart_items"
    private let restaurantIdKey = "cart_restaurant_id"
    private let restaurantNameKey = "cart_restaurant_name"
    
    // Tax rate (5%)
    private let taxRate: Double = 0.05
    
    // MARK: - Computed Properties
    
    var itemCount: Int {
        items.reduce(0) { $0 + $1.quantity }
    }
    
    var subtotal: Double {
        items.reduce(0) { $0 + $1.totalPrice }
    }
    
    var tax: Double {
        subtotal * taxRate
    }
    
    var total: Double {
        subtotal + tax
    }
    
    var isEmpty: Bool {
        items.isEmpty
    }
    
    // MARK: - Initialization
    
    init() {
        loadCart()
        loadRestaurantId()
        loadRestaurantName()
    }
    
    // MARK: - Cart Operations
    
    /// Add item to cart (locks price at add time)
    /// - Parameters:
    ///   - dish: The dish to add
    ///   - quantity: Number of items to add (default: 1)
    ///   - onConflict: Callback triggered when trying to add from different restaurant
    func addItem(_ dish: Dish, quantity: Int = 1, onConflict: (() -> Void)? = nil) {
        // CRITICAL: Enforce single restaurant per cart
        if let currentRestaurantId = restaurantId, currentRestaurantId != dish.restaurant_id {
            onConflict?()  // Trigger alert in UI
            return
        }
        
        // Check if item already exists
        if let index = items.firstIndex(where: { $0.dishId == dish.id }) {
            // Update quantity
            items[index].quantity += quantity
        } else {
            // Add new item with LOCKED price
            let cartItem = CartItem(dish: dish, quantity: quantity)
            items.append(cartItem)
        }
        
        // Set restaurant ID if not set
        if restaurantId == nil {
            restaurantId = dish.restaurant_id
        }
    }
    
    /// Remove item from cart
    func removeItem(_ itemId: String) {
        items.removeAll { $0.id == itemId }
        
        // Clear restaurant data if cart is empty
        if items.isEmpty {
            restaurantId = nil
            restaurantName = nil
        }
    }
    
    /// Update item quantity
    func updateQuantity(itemId: String, quantity: Int) {
        guard quantity > 0 else {
            removeItem(itemId)
            return
        }
        
        if let index = items.firstIndex(where: { $0.id == itemId }) {
            items[index].quantity = quantity
        }
    }
    
    /// Clear entire cart
    func clear() {
        items = []
        restaurantId = nil
        restaurantName = nil
    }
    
    /// Check if adding dish from different restaurant
    func isDifferentRestaurant(_ dish: Dish) -> Bool {
        guard let currentRestaurantId = restaurantId else { return false }
        return currentRestaurantId != dish.restaurant_id
    }
    
    // MARK: - Persistence
    
    /// Save cart to UserDefaults
    private func saveCart() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: cartItemsKey)
        }
    }
    
    /// Load cart from UserDefaults
    private func loadCart() {
        guard let data = UserDefaults.standard.data(forKey: cartItemsKey),
              let decoded = try? JSONDecoder().decode([CartItem].self, from: data) else {
            return
        }
        items = decoded
    }
    
    /// Save restaurant ID to UserDefaults
    private func saveRestaurantId() {
        UserDefaults.standard.set(restaurantId, forKey: restaurantIdKey)
    }
    
    /// Load restaurant ID from UserDefaults
    private func loadRestaurantId() {
        restaurantId = UserDefaults.standard.string(forKey: restaurantIdKey)
    }
    
    /// Save restaurant name to UserDefaults
    private func saveRestaurantName() {
        UserDefaults.standard.set(restaurantName, forKey: restaurantNameKey)
    }
    
    /// Load restaurant name from UserDefaults
    private func loadRestaurantName() {
        restaurantName = UserDefaults.standard.string(forKey: restaurantNameKey)
    }
}
