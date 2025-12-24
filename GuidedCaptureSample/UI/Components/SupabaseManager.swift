import Foundation
import Combine

class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    
    private var accessToken: String?
    
    // MARK: - Auth
    
    func login(email: String, password: String) async throws {
        let url = SupabaseConfig.authURL.appendingPathComponent("token").appending(queryItems: [URLQueryItem(name: "grant_type", value: "password")])
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let session = try JSONDecoder().decode(AuthSession.self, from: data)
        self.accessToken = session.access_token
        self.currentUser = session.user
        
        await MainActor.run {
            self.isAuthenticated = true
        }
    }
    
    func signup(email: String, password: String) async throws {
        let url = SupabaseConfig.authURL.appendingPathComponent("signup")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
    
    func getOAuthURL(provider: String) -> URL? {
        var components = URLComponents(url: SupabaseConfig.authURL.appendingPathComponent("authorize"), resolvingAgainstBaseURL: true)
        components?.queryItems = [
            URLQueryItem(name: "provider", value: provider),
            URLQueryItem(name: "redirect_to", value: "foodview3d://login-callback") // Custom scheme
        ]
        return components?.url
    }
    
    func handleRedirectURL(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let fragment = components.fragment else { return }
        
        // Parse fragment manually since URLComponents doesn't parse it automatically
        var queryItems: [String: String] = [:]
        let pairs = fragment.components(separatedBy: "&")
        for pair in pairs {
            let elements = pair.components(separatedBy: "=")
            if elements.count == 2 {
                queryItems[elements[0]] = elements[1]
            }
        }
        
        if let accessToken = queryItems["access_token"] {
            self.accessToken = accessToken
            
            Task {
                do {
                    try await fetchUser()
                    await MainActor.run {
                        self.isAuthenticated = true
                    }
                } catch {
                    print("Error fetching user: \(error)")
                    // Still set authenticated as we have a token, but user data might be missing
                    await MainActor.run {
                        self.isAuthenticated = true
                    }
                }
            }
        }
    }
    
    func fetchUser() async throws {
        guard let token = accessToken else { return }
        
        let url = SupabaseConfig.authURL.appendingPathComponent("user")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let user = try JSONDecoder().decode(User.self, from: data)
        await MainActor.run {
            self.currentUser = user
        }
    }
    
    // MARK: - Storage
    
    func uploadModel(fileURL: URL, name: String) async throws -> String {
        guard let token = accessToken else { throw URLError(.userAuthenticationRequired) }
        
        // Assuming a 'models' bucket exists
        let path = "models/\(name).usdz"
        let url = SupabaseConfig.storageURL.appendingPathComponent("object").appendingPathComponent(path)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("model/vnd.usdz+zip", forHTTPHeaderField: "Content-Type")
        
        let data = try Data(contentsOf: fileURL)
        
        let (_, response) = try await URLSession.shared.upload(for: request, from: data)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        // Return public URL
        return "\(SupabaseConfig.url)/storage/v1/object/public/\(path)"
    }
    
    func uploadImage(data: Data, name: String) async throws -> String {
        guard let token = accessToken else { throw URLError(.userAuthenticationRequired) }
        
        let path = "images/\(name).jpg"
        let url = SupabaseConfig.storageURL.appendingPathComponent("object").appendingPathComponent(path)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        
        let (_, response) = try await URLSession.shared.upload(for: request, from: data)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        return "\(SupabaseConfig.url)/storage/v1/object/public/\(path)"
    }
}

// MARK: - Models

struct AuthSession: Codable {
    let access_token: String
    let user: User
}

struct User: Codable {
    let id: String
    let email: String?
}

// MARK: - Dish Model (matches Supabase schema)

struct Dish: Codable, Identifiable {
    let id: String
    let created_at: String?
    let updated_at: String?
    let name: String
    let description: String?
    let price: Double
    let category: String
    let model_url: String
    let thumbnail_url: String?
    let model_file_size: Int?
    let polygon_count: Int?
    let generation_status: String?
    let is_active: Bool?
    let featured: Bool?
    let display_order: Int?
}

// MARK: - Database Extension

extension SupabaseManager {
    
    /// Fetch all active dishes from Supabase
    func fetchDishes() async throws -> [Dish] {
        let url = SupabaseConfig.databaseURL.appendingPathComponent("dishes")
            .appending(queryItems: [
                URLQueryItem(name: "is_active", value: "eq.true"),
                URLQueryItem(name: "order", value: "display_order.asc")
            ])
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let dishes = try JSONDecoder().decode([Dish].self, from: data)
        return dishes
    }
    
    /// Create a new dish in the database
    func createDish(name: String, description: String?, price: Double, category: String, modelURL: String, thumbnailURL: String?) async throws -> Dish {
        guard let token = accessToken else { throw URLError(.userAuthenticationRequired) }
        
        let url = SupabaseConfig.databaseURL.appendingPathComponent("dishes")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("return=representation", forHTTPHeaderField: "Prefer")
        
        let body: [String: Any] = [
            "name": name,
            "description": description ?? "",
            "price": price,
            "category": category,
            "model_url": modelURL,
            "thumbnail_url": thumbnailURL ?? "",
            "is_active": true
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let dishes = try JSONDecoder().decode([Dish].self, from: data)
        guard let dish = dishes.first else {
            throw URLError(.cannotParseResponse)
        }
        
        return dish
    }
}
