import Foundation

struct Restaurant: Identifiable {
    let id: String
    let name: String
    let image: String
    let rating: Double
    let category: String
    let dishes: Int
    var location: String = ""
    var priceRange: String = ""
}
