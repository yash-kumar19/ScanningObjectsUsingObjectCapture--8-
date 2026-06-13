import Foundation

/// Centralized configuration for the application
struct AppConfig {
    /// The base URL for the web application
    static let webBaseURL = "https://see-my-dish.vercel.app"
    
    /// Generates the menu URL for a specific restaurant
    /// - Parameter restaurantId: The unique identifier of the restaurant
    /// - Returns: The full URLString for the restaurant's menu
    static func menuURL(for restaurantId: String) -> String {
        return "\(webBaseURL)/menu/\(restaurantId)"
    }
}
