import Foundation

/// Minimal representation of a menu dish referenced by the cart
/// If your project already defines `Dish`, you can delete this one and use your existing model as long as it provides these fields.
public struct Dish: Codable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let price: Double
    public let restaurant_id: String
    public let image_url: String?

    public init(id: String, name: String, price: Double, restaurant_id: String, image_url: String? = nil) {
        self.id = id
        self.name = name
        self.price = price
        self.restaurant_id = restaurant_id
        self.image_url = image_url
    }
}

/// Item stored in the shopping cart
public struct CartItem: Codable, Identifiable, Equatable {
    /// Unique id for the cart line item (separate from the dish id)
    public let id: String

    /// The id of the dish this cart item refers to
    public let dishId: String

    /// Display name for convenience
    public let name: String

    /// Price locked at the time the item is added to the cart
    public let lockedPrice: Double

    /// Optional image URL for display
    public let imageURL: String?

    /// Quantity in the cart
    public var quantity: Int

    public init(id: String = UUID().uuidString,
                dishId: String,
                name: String,
                lockedPrice: Double,
                imageURL: String? = nil,
                quantity: Int) {
        self.id = id
        self.dishId = dishId
        self.name = name
        self.lockedPrice = lockedPrice
        self.imageURL = imageURL
        self.quantity = quantity
    }

    /// Convenience initializer from a Dish, locking price at add time
    public init(dish: Dish, quantity: Int) {
        self.init(dishId: dish.id,
                  name: dish.name,
                  lockedPrice: dish.price,
                  imageURL: dish.image_url,
                  quantity: quantity)
    }

    /// Total price for this line item (lockedPrice * quantity)
    public var totalPrice: Double { lockedPrice * Double(quantity) }
}
