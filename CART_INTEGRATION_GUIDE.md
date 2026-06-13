# Cart Integration Guide

## Quick Integration Steps for RestaurantDetailsScreen.swift

Since automated editing had issues, here's a simple manual integration guide:

### Step 1: Add State Variable (around line 16)

```swift
@State private var showCartScreen = false  // Add this line
```

### Step 2: Update the `onAddToCart` callback in DishCard (around line 409)

Replace this:
```swift
onAddToCart: {
    // Add to cart logic
},
```

With this:
```swift
onAddToCart: {
    // ✅ Add to cart with price locking
    CartManager.shared.addItem(dish, quantity: 1)
    print("✅ Added \(dish.name) to cart")
},
```

### Step 3: Replace bottom buttons section (around line 437-476)

Replace the entire `bottomActionButtons` computed property with:

```swift
private var bottomActionButtons: some View {
    VStack {
        Spacer()
        
        VStack(spacing: 12) {
            // ✅ Floating Cart Bar (shows only when cart has items)
            FloatingCartBar(cartManager: CartManager.shared) {
                // Navigate to cart screen
                showCartScreen = true
            }
            
            Button(action: { showBookingSheet = true }) {
                Text("Make a Reservation")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(hex: "3b82f6"))
                    .cornerRadius(16)
                    .shadow(color: Color.blue.opacity(0.4), radius: 12, x: 0, y: 4)
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Theme.background.opacity(0), Theme.background.opacity(0.95), Theme.background],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    .ignoresSafeArea(.keyboard)
}
```

### Step 4: Add sheet presentation modifier (around line 202, after the .task modifier)

Add this AFTER the existing `.fullScreenCover(isPresented: $show3DPreview)` block:

```swift
.sheet(isPresented: $showCartScreen) {
    CartScreen(onCheckout: {
        // Will implement checkout in Phase 4
        print("Proceeding to checkout...")
        showCartScreen = false
    })
}
```

## That's it!

With these 4 simple changes, your restaurant details screen will have full cart functionality:
- ✅ Add to Cart buttons work
- ✅ Floating cart bar appears when items are added
- ✅ Cart screen shows with full item management
- ✅ Ready for Phase 4 (checkout flow)
