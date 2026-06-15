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
    var onViewOrderStatus: (() -> Void)?   // nil when no pending order
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Color.clear.frame(width: 40)
                
                Spacer()
                
                Text("Cart")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Order Status shortcut
                if let callback = onViewOrderStatus {
                    Button(action: callback) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Order")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(Color(hex: "3B82F6"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(hex: "3B82F6").opacity(0.12))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color(hex: "3B82F6").opacity(0.3), lineWidth: 1))
                    }
                } else {
                    Color.clear.frame(width: 40)
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
    CartScreen(onCheckout: {})
}
