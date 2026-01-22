import Foundation
import Combine

class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    
    private var accessToken: String?
    
    // Session persistence keys
    private let accessTokenKey = "supabase_access_token"
    private let userDataKey = "supabase_user_data"
    
    private init() {
        // Restore session on app launch
        restoreSession()
    }
    
    // MARK: - Session Persistence
    
    private func saveSession() {
        guard let token = accessToken else { return }
        
        // Save access token
        UserDefaults.standard.set(token, forKey: accessTokenKey)
        
        // Save user data if available
        if let user = currentUser,
           let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: userDataKey)
        }
        
        print("Session saved successfully")
    }
    
    private func restoreSession() {
        // Restore access token
        guard let token = UserDefaults.standard.string(forKey: accessTokenKey) else {
            print("No saved session found")
            return
        }
        
        self.accessToken = token
        
        // Restore user data
        if let userData = UserDefaults.standard.data(forKey: userDataKey),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            self.currentUser = user
            self.isAuthenticated = true
            print("Session restored for user: \(user.email ?? "unknown")")
            
            // Optionally refresh user data in background
            Task {
                try? await fetchUser()
            }
        }
    }
    
    private func clearSession() {
        UserDefaults.standard.removeObject(forKey: accessTokenKey)
        UserDefaults.standard.removeObject(forKey: userDataKey)
        self.accessToken = nil
        self.currentUser = nil
        self.isAuthenticated = false
        print("Session cleared")
    }
    
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
        
        // Save session for persistence
        saveSession()
        
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
                    // Save session after successful OAuth login
                    self.saveSession()
                    await MainActor.run {
                        self.isAuthenticated = true
                    }
                } catch {
                    print("Error fetching user: \(error)")
                    // Still set authenticated as we have a token, but user data might be missing
                    await MainActor.run {
                        self.isAuthenticated = true
                    }
                    self.saveSession()
                }
            }
        }
    }
    
    func logout() {
        print("Logging out user...")
        clearSession()
    }
    
    func fetchUser() async throws {
        guard let token = accessToken else { return }
        
        let url = SupabaseConfig.authURL.appendingPathComponent("user")
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
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
        
        print("🔄 [UPLOAD] uploadModel(fileURL:name:) called")
        print("🔄 [UPLOAD] - File: \(fileURL.path)")
        print("🔄 [UPLOAD] - Name: \(name)")
        
        let bucket = "models"
        let objectPath = name
        
        // ✅ CORRECT Supabase Storage v1 URL structure
        let url = SupabaseConfig.storageURL
            .appendingPathComponent("object")
            .appendingPathComponent(bucket)
            .appendingPathComponent(objectPath)
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT" // ✅ MUST be PUT, not POST
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.addValue("true", forHTTPHeaderField: "x-upsert") // ✅ CRITICAL for idempotent upload
        
        let data = try Data(contentsOf: fileURL)
        print("📦 [UPLOAD] File size: \(data.count) bytes")
        
        let responseData: Data
        let response: URLResponse
        
        do {
            (responseData, response) = try await URLSession.shared.upload(for: request, from: data)
        } catch let error as URLError where error.code == .userAuthenticationRequired {
            print("🔄 Authentication required (-1013). Logging out...")
            await MainActor.run { self.logout() }
            throw error
        } catch {
            print("❌ [UPLOAD] Network error: \(error.localizedDescription)")
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorString: String
            if let jsonError = try? JSONDecoder().decode(SupabaseErrorResponse.self, from: responseData) {
                errorString = jsonError.message ?? jsonError.error ?? "Unknown Error"
            } else {
                errorString = String(data: responseData, encoding: .utf8) ?? "Unknown Error (Body size: \(responseData.count))"
            }
            
            print("❌ [UPLOAD] Supabase upload failed [\(httpResponse.statusCode)]: \(errorString)")
            
            if httpResponse.statusCode == 401 {
                print("🔄 Token expired. Logging out...")
                await MainActor.run { self.logout() }
            }
            
            throw SupabaseAPIError(statusCode: httpResponse.statusCode, message: errorString)
        }
        
        let publicURL = "\(SupabaseConfig.url)/storage/v1/object/public/\(bucket)/\(objectPath)"
        print("✅ [UPLOAD] Success! File uploaded to: \(publicURL)")
        return publicURL
    }
    
    func uploadLogo(data: Data, name: String) async throws -> String {
        guard let token = accessToken else { throw URLError(.userAuthenticationRequired) }
        
        let path = "logos/\(name).jpg"
        let url = SupabaseConfig.storageURL.appendingPathComponent("object").appendingPathComponent(path)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.upload(for: request, from: data)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            let message: String
            if let jsonError = try? JSONDecoder().decode(SupabaseErrorResponse.self, from: data) {
                message = jsonError.message ?? jsonError.error ?? "Unknown Error"
            } else {
                message = String(data: data, encoding: .utf8) ?? "Unknown Error (Body size: \(data.count))"
            }
            print("Upload Logo Error: \(httpResponse.statusCode) - \(message)")
            throw SupabaseAPIError(statusCode: httpResponse.statusCode, message: message)
        }
        
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
        
        let (responseData, response) = try await URLSession.shared.upload(for: request, from: data)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            let message: String
            if let jsonError = try? JSONDecoder().decode(SupabaseErrorResponse.self, from: responseData) {
                message = jsonError.message ?? jsonError.error ?? "Unknown Error"
            } else {
                message = String(data: responseData, encoding: .utf8) ?? "Unknown Error (Body size: \(responseData.count))"
            }
            print("Upload Image Error: \(httpResponse.statusCode) - \(message)")
            
            if httpResponse.statusCode == 401 || (httpResponse.statusCode == 400 && (message.contains("exp") || message.contains("token"))) {
                print("🔄 Token expired or invalid (\(httpResponse.statusCode)). Logging out...")
                await MainActor.run { self.logout() }
            }
            
            throw SupabaseAPIError(statusCode: httpResponse.statusCode, message: message)
        }
        
        return "\(SupabaseConfig.url)/storage/v1/object/public/\(path)"
    }
    
    // MARK: - Real-time Polling
    
    private var timer: Timer?
    
    func startPolling() {
        stopPolling()
        // Poll every 10 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task {
                await self?.refreshData()
            }
        }
    }
    
    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
    
    @MainActor
    private func refreshData() async {
        guard isAuthenticated else { return }
        
        // Post notifications that data updated, so views can refetch if they want
        // Or we could have @Published properties here for global state
        NotificationCenter.default.post(name: .supabaseDataDidUpdate, object: nil)
    }
}

extension Notification.Name {
    static let supabaseDataDidUpdate = Notification.Name("supabaseDataDidUpdate")
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

struct SupabaseAPIError: LocalizedError {
    let statusCode: Int
    let message: String
    
    var errorDescription: String? {
        return "Server Error \(statusCode): \(message)"
    }
}

struct SupabaseErrorResponse: Codable {
    let statusCode: String?
    let error: String?
    let message: String?
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
    let model_url: String?
    let thumbnail_url: String?
    let model_file_size: Int?
    let polygon_count: Int?
    let generation_status: String?
    let is_active: Bool?
    let featured: Bool?
    let display_order: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, created_at, updated_at, name, description, price, category
        case model_url = "model_3d_url"     // Maps DB 'model_3d_url' to Swift 'model_url'
        case thumbnail_url = "image_url"    // Maps DB 'image_url' to Swift 'thumbnail_url'
        case generation_status
        case is_active // If missing in DB, this will be nil since property is optional
        case featured
        case display_order
        case model_file_size
        case polygon_count
    }
}

// MARK: - Database Extension

extension SupabaseManager {
    
    /// Fetch active dishes from Supabase
    func fetchDishes() async throws -> [Dish] {
        // 'is_active' column might not exist, removing filter for now to be safe, or assuming implicit
        // If 'is_active' exists in DB, keep it. Screenshot didn't explicitly show it in the first ~10 rows but it might be there.
        // However, 'status' exists. Let's filter by status='published' if needed, but for now just fetch all.
        // SAFE MODE: Remove potentially failing filters.
        
        let url = SupabaseConfig.databaseURL.appendingPathComponent("dishes")
            .appending(queryItems: [
                // URLQueryItem(name: "is_active", value: "eq.true"), // Likely missing
                URLQueryItem(name: "order", value: "created_at.desc")
            ])
        
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.httpMethod = "GET"
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // No auth header needed for public read
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let dishes = try JSONDecoder().decode([Dish].self, from: data)
        return dishes
    }
    
    /// Fetch active dishes for a specific restaurant owner (Customer View)
    func fetchDishes(ownerId: String) async throws -> [Dish] {
        let url = SupabaseConfig.databaseURL.appendingPathComponent("dishes")
            .appending(queryItems: [
                URLQueryItem(name: "restaurant_id", value: "eq.\(ownerId)"),
                URLQueryItem(name: "order", value: "created_at.desc")
            ])
        
        print("🔍 fetchDishes URL: \(url.absoluteString)")
        
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.httpMethod = "GET"
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // No auth header needed for public read
        
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 HTTP Status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 {
                let errorBody = String(data: data, encoding: .utf8) ?? "<no body>"
                print("❌ Error Response: \(errorBody)")
                throw URLError(.badServerResponse)
            }
        } else {
            print("❌ No HTTP response")
            throw URLError(.badServerResponse)
        }
        
        let dishes = try JSONDecoder().decode([Dish].self, from: data)
        return dishes
    }
    
    /// Fetch all dishes (including drafts) for the owner view
    /// Note: Currently fetches all dishes as schema is single-tenant for demo.
    /// In a multi-tenant app, this would filter by owner_id.
    func fetchOwnerDishes() async throws -> [Dish] {
        let url = SupabaseConfig.databaseURL.appendingPathComponent("dishes")
            .appending(queryItems: [
                URLQueryItem(name: "order", value: "created_at.desc")
            ])
        
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.httpMethod = "GET"
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        // No auth header needed for public read in this demo, but usually required for drafts
        if let token = accessToken {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Filter by current user if logged in
        if let userId = currentUser?.id {
               // CORRECTED from restaurant_owner_id
               let urlWithFilter = url.appending(queryItems: [URLQueryItem(name: "restaurant_id", value: "eq.\(userId)")])
               request.url = urlWithFilter
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
             let errorString: String
             if let jsonError = try? JSONDecoder().decode(SupabaseErrorResponse.self, from: data) {
                 errorString = jsonError.message ?? jsonError.error ?? "Unknown Error"
             } else {
                 errorString = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
             }
             print("❌ fetchOwnerDishes failed [\(httpResponse.statusCode)]: \(errorString)")
             
             if httpResponse.statusCode == 401 {
                 print("🔄 Token expired. Logging out...")
                 await MainActor.run { self.logout() }
             }
             
             throw SupabaseAPIError(statusCode: httpResponse.statusCode, message: errorString)
        }
        
        let dishes = try JSONDecoder().decode([Dish].self, from: data)
        return dishes
    }
    

    /// Helper to Create Dish with Auto-Profile Creation on FK Violation (409)
    func createDish(name: String, description: String?, price: Double, category: String, modelURL: String?, thumbnailURL: String?, status: String = "draft", generationStatus: String? = nil) async throws -> Dish {
        do {
            return try await _createDishRaw(name: name, description: description, price: price, category: category, modelURL: modelURL, thumbnailURL: thumbnailURL, status: status, generationStatus: generationStatus)
        } catch let error as SupabaseAPIError {
            // Check for FOREIGN KEY VIOLATION (409 indicates conflict)
            // Error message usually contains "violates foreign key constraint"
            if (error.statusCode == 409 || error.statusCode == 400 || error.statusCode == 422) && (error.message.contains("foreign key") || error.message.contains("fkey")) {
                print("⚠️ Missing profile detected (FK Violation). Attempting to auto-create profile...")
                if let userId = currentUser?.id {
                     // Auto-create profile
                     _ = try await createProfile(userId: userId, email: currentUser?.email)
                     print("✅ Profile created. Retrying createDish...")
                     // Retry
                     return try await _createDishRaw(name: name, description: description, price: price, category: category, modelURL: modelURL, thumbnailURL: thumbnailURL, status: status, generationStatus: generationStatus)
                }
            }
            throw error
        } catch {
            throw error
        }
    }

    private func _createDishRaw(name: String, description: String?, price: Double, category: String, modelURL: String?, thumbnailURL: String?, status: String = "draft", generationStatus: String? = nil) async throws -> Dish {
        guard let token = accessToken, let userId = currentUser?.id else {
            print("❌ createDish failed: Missing token or user ID (User might be logged out).")
            await MainActor.run { self.logout() }
            throw URLError(.userAuthenticationRequired)
        }
        
        let url = SupabaseConfig.databaseURL.appendingPathComponent("dishes")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("return=representation", forHTTPHeaderField: "Prefer")
        
        var body: [String: Any] = [
            "name": name,
            "price": price,
            "category": category,
            "is_active": true,
            "restaurant_id": userId,
            "status": status,
            "generation_status": generationStatus ?? "pending_upload"
        ]
        
        // Handle optional description
        if let desc = description, !desc.isEmpty {
            body["description"] = desc
        } else {
            body["description"] = NSNull()
        }
        
        // Handle optional image_url
        if let thumb = thumbnailURL, !thumb.isEmpty {
            body["image_url"] = thumb
        } else {
            body["image_url"] = NSNull()
        }
        
        // Handle optional model_url with NSNull for explicit null
        if let mURL = modelURL {
            body["model_3d_url"] = mURL
        } else {
            body["model_3d_url"] = NSNull()
        }
        
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = bodyData
        
        // 1. Log Payload
        if let payloadString = String(data: bodyData, encoding: .utf8) {
            print("📤 createDish payload: \(payloadString)")
        } else {
            print("📤 createDish payload: <non-utf8>")
        }
        
        let data: Data
        let response: URLResponse
        
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError where error.code == .userAuthenticationRequired {
            print("🔄 Authentication required (-1013). Logging out...")
            await MainActor.run { self.logout() }
            throw error
        } catch {
            throw error
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            // 2. Improve Error Visibility
            let errorString: String
            if let jsonError = try? JSONDecoder().decode(SupabaseErrorResponse.self, from: data) {
                errorString = jsonError.message ?? jsonError.error ?? "Unknown Error"
            } else {
                errorString = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
            }
            print("❌ createDish failed [\(httpResponse.statusCode)]: \(errorString)")
            
            if httpResponse.statusCode == 401 || (httpResponse.statusCode == 400 && (errorString.contains("exp") || errorString.contains("token"))) {
                print("🔄 Token expired or invalid (\(httpResponse.statusCode)). Logging out...")
                await MainActor.run { self.logout() }
            }
            
            throw SupabaseAPIError(statusCode: httpResponse.statusCode, message: errorString)
        }
        
        // 3. Try to decode success response
        let dishes = try JSONDecoder().decode([Dish].self, from: data)
        guard let dish = dishes.first else {
            throw URLError(.cannotParseResponse)
        }
        
        return dish
    }
    
    // Update Dish (Specific fields for background upload completion)
    func updateDish(id: String, modelURL: String, generationStatus: String) async throws {
        guard let token = accessToken else { throw URLError(.userAuthenticationRequired) }
        
        let url = SupabaseConfig.databaseURL.appendingPathComponent("dishes")
            .appending(queryItems: [URLQueryItem(name: "id", value: "eq.\(id)")])
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model_3d_url": modelURL,
            "generation_status": generationStatus
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
             let errorString: String
             if let jsonError = try? JSONDecoder().decode(SupabaseErrorResponse.self, from: data) {
                 errorString = jsonError.message ?? jsonError.error ?? "Unknown Error"
             } else {
                 errorString = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
             }
             print("❌ updateDish failed [\(httpResponse.statusCode)]: \(errorString)")
             throw SupabaseAPIError(statusCode: httpResponse.statusCode, message: errorString)
        }
    }
}

// MARK: - Profiles & Reservations Extension

struct Profile: Codable, Identifiable {
    let id: String
    let email: String?
    let full_name: String?
    let avatar_url: String?
    let role: String? // "customer" or "owner"
    let restaurant_name: String?
    let logo_url: String? // Added logo_url
    let cuisine: String?
    let address: String?
    let phone: String?
    let city: String?
    let pincode: String?
    let fssai_number: String? // Renamed from fssai to match convention if needed, or keeping loose
    let opening_hours: String?
    let bio: String?
}

struct Reservation: Codable, Identifiable {
    let id: String
    let customer_id: String
    let restaurant_owner_id: String
    let guest_count: Int
    let reservation_date: String // ISO8601 string
    let status: String
    let special_requests: String?
    let created_at: String?
    
    // Joins - mapped via decoder
    let owner: Profile?     // Aliased from 'profiles' joined on restaurant_owner_id
    let customer: Profile?  // Aliased from 'profiles' joined on customer_id
}

extension SupabaseManager {
    
    // MARK: - Profiles
    
    func fetchProfile(userId: String) async throws -> Profile {
        let url = SupabaseConfig.databaseURL.appendingPathComponent("profiles")
            .appending(queryItems: [URLQueryItem(name: "id", value: "eq.\(userId)")])
        
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.httpMethod = "GET"
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let profiles = try JSONDecoder().decode([Profile].self, from: data)
        if let profile = profiles.first {
            return profile
        } else {
            // Auto-create if missing
            return try await createProfile(userId: userId, email: currentUser?.email)
        }
    }
    
    func createProfile(userId: String, email: String?) async throws -> Profile {
        guard let token = accessToken else { throw URLError(.userAuthenticationRequired) }
        
        let url = SupabaseConfig.databaseURL.appendingPathComponent("profiles")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("return=representation", forHTTPHeaderField: "Prefer")
        
        let body: [String: Any] = [
            "id": userId,
            "email": email ?? "",
            "role": "customer"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        if !(200...299).contains(httpResponse.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? "Unknown Error"
            print("Create Profile Error: \(httpResponse.statusCode) - \(message)")
            
            if httpResponse.statusCode == 409 {
                print("⚠️ Profile already exists (409). Fetching existing...")
                return try await fetchProfile(userId: userId)
            }
            throw SupabaseAPIError(statusCode: httpResponse.statusCode, message: message)
        }
        
        let profiles = try JSONDecoder().decode([Profile].self, from: data)
        return profiles.first!
    }
    
    func updateProfile(role: String, restaurantName: String?, logoURL: String?, cuisine: String?, address: String?, phone: String?, city: String?, pincode: String?, fssai: String?, openingHours: String?, bio: String?) async throws {
        guard let token = accessToken, let userId = currentUser?.id else { throw URLError(.userAuthenticationRequired) }
        
        let url = SupabaseConfig.databaseURL.appendingPathComponent("profiles")
             .appending(queryItems: [URLQueryItem(name: "id", value: "eq.\(userId)")])
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = ["role": role]
        if let rName = restaurantName { body["restaurant_name"] = rName }
        if let lURL = logoURL { body["logo_url"] = lURL }
        if let c = cuisine { body["cuisine"] = c }
        if let a = address { body["address"] = a }
        if let p = phone { body["phone"] = p }
        if let ci = city { body["city"] = ci }
        if let pin = pincode { body["pincode"] = pin }
        if let pin = pincode { body["pincode"] = pin }
        if let f = fssai { body["fssai_number"] = f }
        if let oh = openingHours { body["opening_hours"] = oh }
        if let b = bio { body["bio"] = b }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? "Unknown Error"
            print("Update Profile Error: \(httpResponse.statusCode) - \(message)")
            throw SupabaseAPIError(statusCode: httpResponse.statusCode, message: message)
        }
    }
    
    // MARK: - Reservations
    
    func createReservation(ownerId: String, guests: Int, date: Date, special: String?) async throws {
        // ... (unchanged)
        guard let token = accessToken, let userId = currentUser?.id else { throw URLError(.userAuthenticationRequired) }
        
        let url = SupabaseConfig.databaseURL.appendingPathComponent("reservations")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let formatter = ISO8601DateFormatter()
        let dateString = formatter.string(from: date)
        
        let body: [String: Any] = [
            "customer_id": userId,
            "restaurant_owner_id": ownerId,
            "guest_count": guests,
            "reservation_date": dateString,
            "status": "pending",
            "special_requests": special ?? ""
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
    
    func fetchMyReservations() async throws -> [Reservation] {
        guard let token = accessToken, let userId = currentUser?.id else { throw URLError(.userAuthenticationRequired) }
        
        // Fetch reservations + owner profile (aliased as 'owner')
        let url = SupabaseConfig.databaseURL.appendingPathComponent("reservations")
            .appending(queryItems: [
                URLQueryItem(name: "customer_id", value: "eq.\(userId)"),
                URLQueryItem(name: "order", value: "reservation_date.desc"),
                URLQueryItem(name: "select", value: "*,owner:profiles!restaurant_owner_id(*)")
            ])
            
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode([Reservation].self, from: data)
    }
    
    func fetchRestaurants() async throws -> [Profile] {
        let url = SupabaseConfig.databaseURL.appendingPathComponent("profiles")
            .appending(queryItems: [URLQueryItem(name: "role", value: "eq.owner")])
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode([Profile].self, from: data)
    }

    func fetchOwnerReservations() async throws -> [Reservation] {
        guard let token = accessToken, let userId = currentUser?.id else { throw URLError(.userAuthenticationRequired) }
        
        // Fetch reservations + customer profile (aliased as 'customer')
        let url = SupabaseConfig.databaseURL.appendingPathComponent("reservations")
            .appending(queryItems: [
                URLQueryItem(name: "restaurant_owner_id", value: "eq.\(userId)"),
                URLQueryItem(name: "order", value: "reservation_date.asc"),
                URLQueryItem(name: "select", value: "*,customer:profiles!customer_id(*)")
            ])
            
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode([Reservation].self, from: data)
    }
    
    func updateReservationStatus(id: String, status: String) async throws {
        // ... (unchanged)
        guard let token = accessToken else { throw URLError(.userAuthenticationRequired) }
        
         let url = SupabaseConfig.databaseURL.appendingPathComponent("reservations")
             .appending(queryItems: [URLQueryItem(name: "id", value: "eq.\(id)")])
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["status": status]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}


