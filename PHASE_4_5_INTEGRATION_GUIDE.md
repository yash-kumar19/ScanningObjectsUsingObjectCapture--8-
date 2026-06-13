# Phase 4-5 Integration Guide

## Navigation Flow Integration

You now have the complete customer ordering flow! Here's how to connect everything:

### Step 1: Update CartScreen.swift

The `onCheckout` callback in `CartScreen` should navigate to the order confirmation screen.

In your navigation logic (likely in `HomeView` or wherever you show the CartScreen), update it to:

```swift
.sheet(isPresented: $showCartScreen) {
    CartScreen(onCheckout: {
        showCartScreen = false
        // Navigate to order confirmation
        showOrderConfirmation = true
    })
}
.sheet(isPresented: $showOrderConfirmation) {
    OrderConfirmationScreen(
        restaurantId: currentRestaurantId,  // Pass the current restaurant ID
        onOrderPlaced: { orderId in
            // Navigate to order status screen
            orderIdToTrack = orderId
            showOrderStatus = true
        }
    )
    .environmentObject(SupabaseManager.shared)
}
.sheet(isPresented: $showOrderStatus) {
    if let orderId = orderIdToTrack {
        CustomerOrderStatusScreen(orderId: orderId)
    }
}
```

### Step 2: Add State Variables

Add these to your main navigation view:

```swift
@State private var showOrderConfirmation = false
@State private var showOrderStatus = false
@State private var orderIdToTrack: String?
@State private var currentRestaurantId: String = ""  // Set this when user browses a restaurant
```

### Step 3: Track Restaurant ID

When user views a restaurant's menu (in `RestaurantDetailsScreenV2`), make sure to store the restaurant ID:

```swift
// In RestaurantDetailsScreenV2 or parent view
@State private var currentRestaurantId: String = ""

// Set it when screen appears
.onAppear {
    currentRestaurantId = restaurantProfile.id
}
```

## Complete User Flow

1. **Browse Menu** → User sees dishes in `RestaurantDetailsScreenV2`
2. **Add to Cart** → Tap dish "+" button → `CartManager.shared.addItem(dish)`
3. **View Cart** → Tap `FloatingCartBar` → Shows `CartScreen`
4. **Proceed to Checkout** → Tap "Place Order" in cart → Shows `OrderConfirmationScreen`
5. **Confirm Order** → Enter name, notes → Tap "Place Order" → Creates order in database
6. **Track Order** → Auto-navigates to `CustomerOrderStatusScreen` → Polls every 5 seconds
7. **Receive Updates** → Owner updates status → Customer sees progress automatically

## What Happens Behind the Scenes

### When Order is Placed:
1. `OrderConfirmationScreen` calls `SupabaseManager.shared.createOrder()`
2. Order is created with client-side UUID (prevents duplicates)
3. Order items are created in `order_items` table
4. Cart is cleared via `CartManager.shared.clear()`
5. Navigation proceeds to status screen with order ID

### During Order Tracking:
1. `OrderPollingManager` starts 5-second polling
2. `fetchOrderById()` is called every 5 seconds
3. UI updates automatically when status changes
4. Polling stops when user dismisses screen

## Testing Checklist

- [ ] Can add items to cart
- [ ] Cart persists across app restarts
- [ ] FloatingCartBar shows correct count and total
- [ ] Cart screen shows all items with correct prices
- [ ] Can update quantities in cart
- [ ] Can remove items from cart
- [ ] Order confirmation shows all details correctly
- [ ] "Place Order" button is disabled when name field is empty
- [ ] "Place Order" shows loading state
- [ ] Order is created in database with correct data
- [ ] Cart is cleared after successful order
- [ ] Navigation flows to order status screen
- [ ] Order status screen polls every 5 seconds
- [ ] Status updates appear automatically
- [ ] Pull-to-refresh works
- [ ] Polling stops when leaving screen

## Next Steps: Phase 6 (Owner Dashboard)

After integration, you'll need to implement the owner-facing dashboard where restaurant owners can:
- View incoming orders
- Update order status (Received → Preparing → Ready → Completed)
- See order details
- Manage orders by status tabs

This will complete the full ordering loop!
