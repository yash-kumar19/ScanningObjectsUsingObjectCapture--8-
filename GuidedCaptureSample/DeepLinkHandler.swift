import Foundation
import SwiftUI

/// Deep Link Handler for Universal Links and Custom URL Schemes
/// Handles /menu/{restaurant_id} routing with edge case validation
@MainActor
class DeepLinkHandler: ObservableObject {
    static let shared = DeepLinkHandler()
    
    // Published properties for navigation
    @Published var pendingRestaurantId: String?
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    
    private init() {}
    
    /// Handle incoming URL from Universal Link or custom scheme
    /// - Parameter url: The URL to process
    /// - Returns: True if URL was handled, false otherwise
    func handleURL(_ url: URL) -> Bool {
        print("🔗 [DeepLink] Handling URL: \(url.absoluteString)")
        
        // Parse the URL path
        let path = url.path
        
        // Check if it's a menu link: /menu/{restaurant_id}
        if path.hasPrefix("/menu/") {
            let restaurantId = String(path.dropFirst("/menu/".count))
            return handleMenuDeepLink(restaurantId: restaurantId)
        }
        
        // Handle OAuth callback (existing)
        if url.host == "login-callback" || url.scheme == "foodview3d" {
            // Let SupabaseManager handle OAuth
            SupabaseManager.shared.handleRedirectURL(url)
            return true
        }
        
        print("⚠️ [DeepLink] Unknown URL format: \(url.absoluteString)")
        return false
    }
    
    /// Handle menu deep link with validation
    /// - Parameter restaurantId: The restaurant ID from the URL
    /// - Returns: True if handled successfully
    private func handleMenuDeepLink(restaurantId: String) -> Bool {
        print("🍽️ [DeepLink] Menu link detected for restaurant: \(restaurantId)")
        
        // Edge Case 1: Validate restaurant ID format (UUID)
        guard isValidUUID(restaurantId) else {
            print("❌ [DeepLink] Invalid restaurant ID format")
            showErrorAlert(message: "Invalid restaurant link. Please check the QR code.")
            return false
        }
        
        // Edge Case 2 & 3: Validate restaurant exists and is active (async)
        // We can't do async validation here, so we'll set the pending ID
        // and let the view handle validation with a guarded fetch
        Task {
            await validateAndNavigate(restaurantId: restaurantId)
        }
        
        return true
    }
    
    /// Validate restaurant and navigate (async with edge case handling)
    /// - Parameter restaurantId: Restaurant ID to validate
    private func validateAndNavigate(restaurantId: String) async {
        do {
            // Edge Case 3: Network unavailable - will throw error
            let isActive = try await SupabaseManager.shared.isRestaurantActive(restaurantId: restaurantId)
            
            // Edge Case 2: Restaurant inactive
            guard isActive else {
                print("⚠️ [DeepLink] Restaurant is inactive")
                showErrorAlert(message: "This restaurant is currently unavailable.")
                return
            }
            
            // ✅ Valid restaurant - trigger navigation
            print("✅ [DeepLink] Restaurant validated, navigating...")
            pendingRestaurantId = restaurantId
            
        } catch {
            // Edge Case 3: Network failure or validation error
            print("❌ [DeepLink] Validation failed: \(error.localizedDescription)")
            
            // Check if we have cached data for this restaurant
            let hasCachedData = false // TODO: Implement cache check
            
            if hasCachedData {
                // Show cached menu with retry option
                pendingRestaurantId = restaurantId
                showErrorAlert(message: "Unable to connect. Showing cached menu.", allowRetry: true)
            } else {
                // Show error without cached fallback
                showErrorAlert(message: "Unable to load menu. Please check your connection and try again.")
            }
        }
    }
    
    /// Show error alert to user
    /// - Parameters:
    ///   - message: Error message to display
    ///   - allowRetry: Whether to show a retry option
    private func showErrorAlert(message: String, allowRetry: Bool = false) {
        errorMessage = message
        showError = true
    }
    
    /// Validate UUID format
    /// - Parameter id: String to validate
    /// - Returns: True if valid UUID format
    private func isValidUUID(_ id: String) -> Bool {
        return UUID(uuidString: id) != nil
    }
    
    /// Clear pending navigation state
    func clearPendingNavigation() {
        pendingRestaurantId = nil
    }
}

// MARK: - Deep Link Destination

/// Represents a deep link destination
enum DeepLinkDestination: Identifiable {
    case restaurantMenu(restaurantId: String)
    
    var id: String {
        switch self {
        case .restaurantMenu(let restaurantId):
            return "menu_\(restaurantId)"
        }
    }
}
