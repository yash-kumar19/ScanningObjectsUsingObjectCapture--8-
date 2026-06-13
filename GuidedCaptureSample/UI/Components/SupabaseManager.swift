import Foundation
import Combine

enum LoginIntent {
    case none
    case owner
    case customer
}

class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var userRole: String?
    @Published var loginIntent: LoginIntent = .none
    @Published var isRestoringSession = false
    
    var isOwner: Bool {
        userRole == "owner"
    }
    
    var accessToken: String? {
        didSet {
            if let token = accessToken {
                scheduleRefreshTimer(for: token)
            }
        }
    }
    var refreshToken: String?
    
    // Session persistence keys
    private let accessTokenKey = "supabase_access_token"
    private let refreshTokenKey = "supabase_refresh_token"
    private let userDataKey = "supabase_user_data"
    
    private init() {
        // Restore session on app launch
        restoreSession()
        
        // Listen for app foregrounding to check and refresh token
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: NSNotification.Name("UIApplicationWillEnterForegroundNotification"),
            object: nil
        )
    }
    
    @objc private func appWillEnterForeground() {
        print("📱 App returned to foreground, checking token status...")
        Task {
            if isAuthenticated {
                _ = try? await getValidAccessTokenOrRefresh()
            }
        }
    }
    
    // MARK: - Session Persistence
    
    private func saveSession() {
        guard let token = accessToken else { return }
        
        // Save access token
        UserDefaults.standard.set(token, forKey: accessTokenKey)
        
        // Save refresh token if available
        if let rToken = refreshToken {
            UserDefaults.standard.set(rToken, forKey: refreshTokenKey)
        }
        
        // Save user data if available
        if let user = currentUser,
           let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: userDataKey)
        }
        
        print("Session saved successfully")
    }
    
    private func restoreSession() {
        // Restore refresh token first to be available when accessToken is set
        self.refreshToken = UserDefaults.standard.string(forKey: refreshTokenKey)
        
        // Restore access token
        guard let token = UserDefaults.standard.string(forKey: accessTokenKey) else {
            print("No saved session found")
            return
        }
        
        self.isRestoringSession = true
        self.accessToken = token
        
        // Restore user data
        if let userData = UserDefaults.standard.data(forKey: userDataKey),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            self.currentUser = user
            self.isAuthenticated = true
            print("Session restored for user: \(user.email ?? "unknown")")
            
            // Refresh user data and role in background
            Task {
                defer {
                    DispatchQueue.main.async {
                        self.isRestoringSession = false
                    }
                }
                if self.refreshToken != nil {
                    do {
                        _ = try await getValidAccessTokenOrRefresh()
                    } catch {
                        print("⚠️ Failed to verify or refresh token during session restore: \(error)")
                    }
                }
                
                try? await fetchUser()
                if let userId = currentUser?.id {
                    let profile = try? await fetchProfile(userId: userId)
                    await MainActor.run {
                        self.userRole = profile?.role
                    }
                }
            }
        } else {
            self.isRestoringSession = false
        }
    }
    
    private func clearSession() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        
        UserDefaults.standard.removeObject(forKey: accessTokenKey)
        UserDefaults.standard.removeObject(forKey: refreshTokenKey)
        UserDefaults.standard.removeObject(forKey: userDataKey)
        self.accessToken = nil
        self.refreshToken = nil
        self.currentUser = nil
        self.isAuthenticated = false
        print("Session cleared")
    }
    
    // MARK: - JWT Handling & Refreshing
    
    private func getExpirationDate(from token: String) -> Date? {
        let parts = token.components(separatedBy: ".")
        guard parts.count > 1 else { return nil }
        
        var payloadPart = parts[1]
        let paddingCount = 4 - (payloadPart.count % 4)
        if paddingCount < 4 {
            payloadPart += String(repeating: "=", count: paddingCount)
        }
        
        payloadPart = payloadPart.replacingOccurrences(of: "-", with: "+")
        payloadPart = payloadPart.replacingOccurrences(of: "_", with: "/")
        
        guard let data = Data(base64Encoded: payloadPart),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? TimeInterval else {
            return nil
        }
        
        return Date(timeIntervalSince1970: exp)
    }
    
    private func isTokenExpired(_ token: String) -> Bool {
        guard let expirationDate = getExpirationDate(from: token) else { return true }
        let bufferTime: TimeInterval = 300 // 5 minutes buffer
        return expirationDate.compare(Date().addingTimeInterval(bufferTime)) == .orderedAscending
    }
    
    func getValidAccessTokenOrRefresh() async throws -> String {
        guard let token = accessToken else {
            throw URLError(.userAuthenticationRequired)
        }
        
        if !isTokenExpired(token) {
            scheduleRefreshTimer(for: token)
            return token
        }
        
        print("🔄 Token is expired or expiring soon. Refreshing session...")
        return try await refreshSession()
    }
    
    func refreshSession() async throws -> String {
        guard let rToken = refreshToken else {
            print("❌ No refresh token available to renew session")
            await MainActor.run { self.logout() }
            throw URLError(.userAuthenticationRequired)
        }
        
        let url = SupabaseConfig.authURL.appendingPathComponent("token").appending(queryItems: [URLQueryItem(name: "grant_type", value: "refresh_token")])
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["refresh_token": rToken]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            print("❌ refreshSession failed with status \(httpResponse.statusCode): \(errorBody)")
            if httpResponse.statusCode == 400 || httpResponse.statusCode == 401 {
                print("🔄 Refresh token is invalid/expired. Logging out user...")
                await MainActor.run { self.logout() }
            }
            throw URLError(.userAuthenticationRequired)
        }
        
        let session = try JSONDecoder().decode(AuthSession.self, from: data)
        self.accessToken = session.access_token
        self.refreshToken = session.refresh_token
        self.currentUser = session.user
        
        self.saveSession()
        
        print("✅ Session refreshed successfully")
        return session.access_token
    }
    
    private var refreshTimer: Timer?
    
    private func scheduleRefreshTimer(for token: String) {
        guard refreshToken != nil else { return }
        guard let expirationDate = getExpirationDate(from: token) else { return }
        
        // Invalidate existing timer
        refreshTimer?.invalidate()
        
        let timeInterval = expirationDate.timeIntervalSince(Date()) - 300 // 5 minutes before expiration
        guard timeInterval > 0 else {
            // If already within 5 minutes, refresh immediately in background
            Task {
                try? await refreshSession()
            }
            return
        }
        
        print("⏰ Scheduled token refresh in \(Int(timeInterval)) seconds")
        
        DispatchQueue.main.async {
            self.refreshTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
                Task {
                    try? await self?.refreshSession()
                }
            }
        }
    }
    
    // MARK: - Auth
    
    func sendOTP(email: String) async throws {
        let url = SupabaseConfig.authURL.appendingPathComponent("otp")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "email": email,
            "options": [
                "shouldCreateUser": true,
                "emailRedirectTo": "foodview3d://login-callback"
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Failed to send OTP"
            print("❌ sendOTP failed: \(errorMsg)")
            throw URLError(.badServerResponse)
        }
    }
    
    func verifyOTP(email: String, token: String) async throws {
        let url = SupabaseConfig.authURL.appendingPathComponent("verify")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "email": email,
            "token": token,
            "type": "email"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Verification failed"
            print("❌ verifyOTP failed: \(errorMsg)")
            throw URLError(.badServerResponse)
        }
        
        let session = try JSONDecoder().decode(AuthSession.self, from: data)
        self.refreshToken = session.refresh_token
        self.accessToken = session.access_token
        self.currentUser = session.user
        
        // Fetch profile to verify role/roles
        let profile = try? await fetchProfile(userId: session.user.id)
        
        // Persistent save
        self.saveSession()
        
        await MainActor.run {
            self.userRole = profile?.role
            self.isAuthenticated = true
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
            if let refreshToken = queryItems["refresh_token"] {
                self.refreshToken = refreshToken
            }
            self.accessToken = accessToken
            
            Task {
                do {
                    try await fetchUser()
                    let profile = try? await fetchProfile(userId: self.currentUser?.id ?? "")
                    // Save session after successful OAuth login
                    self.saveSession()
                    await MainActor.run {
                        self.userRole = profile?.role
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
        self.userRole = nil
        self.loginIntent = .none
    }
    
    func fetchUser() async throws {
        let token = try await getValidAccessTokenOrRefresh()
        
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
        let token = try await getValidAccessTokenOrRefresh()
        
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
        let token = try await getValidAccessTokenOrRefresh()
        
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
        let token = try await getValidAccessTokenOrRefresh()
        
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
    let refresh_token: String?
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
    let restaurant_id: String  // CRITICAL: Required for cart restaurant validation
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
        case id, created_at, updated_at, restaurant_id, name, description, price, category
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
                URLQueryItem(name: "is_active", value: "eq.true"),  // Filter soft-deleted dishes
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
                URLQueryItem(name: "is_active", value: "eq.true"),  // Filter soft-deleted dishes
                URLQueryItem(name: "order", value: "created_at.desc")
            ])
        
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.httpMethod = "GET"
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        // No auth header needed for public read in this demo, but usually required for drafts
        if let token = try? await getValidAccessTokenOrRefresh() {
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
        let token = try await getValidAccessTokenOrRefresh()
        guard let userId = currentUser?.id else {
            print("❌ createDish failed: Missing user ID (User might be logged out).")
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
        let token = try await getValidAccessTokenOrRefresh()
        
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
    
    // MARK: - Production-Safe Edit & Delete Methods
    
    /// Soft-delete a dish (sets is_active to false instead of hard delete)
    /// This preserves data for recovery and prevents cache inconsistencies
    func softDeleteDish(id: String) async throws {
        let token = try await getValidAccessTokenOrRefresh()
        
        let url = SupabaseConfig.databaseURL.appendingPathComponent("dishes")
            .appending(queryItems: [URLQueryItem(name: "id", value: "eq.\(id)")])
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "is_active": false
            // Note: Not setting status to "deleted" because database has a check constraint
            // that only allows "draft" or "published". The is_active flag is sufficient.
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
            print("❌ softDeleteDish failed [\(httpResponse.statusCode)]: \(errorString)")
            
            if httpResponse.statusCode == 401 {
                print("🔄 Token expired. Logging out...")
                await MainActor.run { self.logout() }
            }
            
            throw SupabaseAPIError(statusCode: httpResponse.statusCode, message: errorString)
        }
        
        print("✅ Dish soft-deleted successfully (id: \(id))")
    }
    
    /// Update dish with partial data (only sends changed fields)
    /// Prevents accidental overwrites of model/image during edits
    func updateDishPartial(
        id: String,
        name: String? = nil,
        description: String? = nil,
        price: Double? = nil,
        category: String? = nil,
        imageURL: String? = nil,
        modelURL: String? = nil,
        generationStatus: String? = nil
    ) async throws {
        let token = try await getValidAccessTokenOrRefresh()
        
        // Build partial update body - only include fields that are provided
        var body: [String: Any] = [:]
        
        if let name = name { body["name"] = name }
        if let description = description {
            body["description"] = description.isEmpty ? NSNull() : description
        }
        if let price = price { body["price"] = price }
        if let category = category { body["category"] = category }
        if let imageURL = imageURL { body["image_url"] = imageURL }
        
        // 🛡️ SAFETY: Respect generation_status to prevent race conditions
        if let modelURL = modelURL {
            // First, fetch current dish to check generation_status
            let currentDish = try await fetchDishById(id: id)
            
            if currentDish.generation_status == "uploading" {
                print("⚠️ Cannot update model_3d_url while upload is in progress")
                throw SupabaseAPIError(
                    statusCode: 409,
                    message: "Cannot update 3D model while upload is in progress. Please wait for upload to complete."
                )
            }
            
            body["model_3d_url"] = modelURL
        }
        
        if let generationStatus = generationStatus {
            body["generation_status"] = generationStatus
        }
        
        // Note: updated_at column doesn't exist in current schema
        // If you want automatic timestamps, add this column to your database:
        // ALTER TABLE dishes ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW();
        
        guard !body.isEmpty else {
            print("⚠️ updateDishPartial called with no fields to update")
            return
        }
        
        let url = SupabaseConfig.databaseURL.appendingPathComponent("dishes")
            .appending(queryItems: [URLQueryItem(name: "id", value: "eq.\(id)")])
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        if let payloadString = String(data: request.httpBody!, encoding: .utf8) {
            print("📤 updateDishPartial payload: \(payloadString)")
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
            print("❌ updateDishPartial failed [\(httpResponse.statusCode)]: \(errorString)")
            
            if httpResponse.statusCode == 401 {
                print("🔄 Token expired. Logging out...")
                await MainActor.run { self.logout() }
            }
            
            throw SupabaseAPIError(statusCode: httpResponse.statusCode, message: errorString)
        }
        
        print("✅ Dish updated successfully (id: \(id))")
    }
    
    /// Helper to fetch a single dish by ID (used for generation_status checks)
    private func fetchDishById(id: String) async throws -> Dish {
        let url = SupabaseConfig.databaseURL.appendingPathComponent("dishes")
            .appending(queryItems: [URLQueryItem(name: "id", value: "eq.\(id)")])
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let dishes = try JSONDecoder().decode([Dish].self, from: data)
        guard let dish = dishes.first else {
            throw URLError(.resourceUnavailable)
        }
        
        return dish
    }
    
    // MARK: - Public API Methods for QR Menu Access
    
    /// Fetch published dishes for a restaurant (public access, no auth required)
    /// Uses explicit column selection to prevent data leaks
    /// - Parameter restaurantId: The restaurant's ID
    /// - Returns: Array of published dishes
    func fetchPublicDishes(restaurantId: String) async throws -> [Dish] {
        // ✅ Security: Explicit column selection - only expose customer-facing data
        let columns = "id,name,price,description,image_url,model_3d_url,category"
        
        let url = SupabaseConfig.databaseURL.appendingPathComponent("dishes")
            .appending(queryItems: [
                URLQueryItem(name: "restaurant_id", value: "eq.\(restaurantId)"),
                URLQueryItem(name: "is_active", value: "eq.true"),
                URLQueryItem(name: "status", value: "eq.published"),
                URLQueryItem(name: "select", value: columns), // ✅ CRITICAL: Explicit columns only
                URLQueryItem(name: "order", value: "created_at.desc")
            ])
        
        print("🔍 [Public API] Fetching dishes for restaurant: \(restaurantId)")
        print("🔍 [Public API] URL: \(url.absoluteString)")
        
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.httpMethod = "GET"
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        // ✅ No Authorization header - public access
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [Public API] No HTTP response")
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "<no body>"
            print("❌ [Public API] Error (\(httpResponse.statusCode)): \(errorBody)")
            throw URLError(.badServerResponse)
        }
        
        let dishes = try JSONDecoder().decode([Dish].self, from: data)
        print("✅ [Public API] Fetched \(dishes.count) dishes")
        return dishes
    }
    
    /// Fetch restaurant profile (public access, no auth required)
    /// - Parameter restaurantId: The restaurant's UUID
    /// - Returns: Restaurant
    func fetchPublicRestaurant(restaurantId: String) async throws -> Restaurant {
        let url = SupabaseConfig.databaseURL.appendingPathComponent("restaurants")
            .appending(queryItems: [
                URLQueryItem(name: "id", value: "eq.\(restaurantId)"),
                URLQueryItem(name: "status", value: "eq.active")
            ])
        
        print("🔍 [Public API] Fetching restaurant profile by ID: \(restaurantId)")
        
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.httpMethod = "GET"
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "<no body>"
            print("❌ [Public API] Restaurant not found (\(httpResponse.statusCode)): \(errorBody)")
            throw URLError(.resourceUnavailable)
        }
        
        let restaurants = try JSONDecoder().decode([Restaurant].self, from: data)
        guard let restaurant = restaurants.first else {
            print("❌ [Public API] No active restaurant found for ID: \(restaurantId)")
            throw URLError(.resourceUnavailable)
        }
        
        print("✅ [Public API] Fetched restaurant: \(restaurant.name)")
        return restaurant
    }
    
    /// Check if a restaurant exists and is active (for deep link validation)
    /// - Parameter restaurantId: The restaurant's user ID
    /// - Returns: True if restaurant exists and is an owner profile
    func isRestaurantActive(restaurantId: String) async throws -> Bool {
        do {
            _ = try await fetchPublicRestaurant(restaurantId: restaurantId)
            return true
        } catch {
            return false
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
    let roles: [String]? // Added for multi-role alignment
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

struct Restaurant: Codable, Identifiable {
    let id: String
    let owner_id: String
    let name: String
    let description: String?
    let address: String?
    let phone: String?
    let logo_url: String?
    let cuisine_type: String?
    let city: String?
    let pincode: String?
    let gallery_urls: [String]?
    let status: String?
    let opening_hours: [String: OpeningHourDay]?

    enum CodingKeys: String, CodingKey {
        case id
        case owner_id
        case name
        case description
        case address
        case phone
        case logo_url
        case cuisine_type
        case city
        case pincode
        case gallery_urls
        case status
        case opening_hours
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.owner_id = try container.decode(String.self, forKey: .owner_id)
        self.name = try container.decode(String.self, forKey: .name)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.address = try container.decodeIfPresent(String.self, forKey: .address)
        self.phone = try container.decodeIfPresent(String.self, forKey: .phone)
        self.logo_url = try container.decodeIfPresent(String.self, forKey: .logo_url)
        self.cuisine_type = try container.decodeIfPresent(String.self, forKey: .cuisine_type)
        self.city = try container.decodeIfPresent(String.self, forKey: .city)
        self.pincode = try container.decodeIfPresent(String.self, forKey: .pincode)
        self.gallery_urls = try container.decodeIfPresent([String].self, forKey: .gallery_urls)
        self.status = try container.decodeIfPresent(String.self, forKey: .status)
        
        // Tolerant decode of opening_hours
        if let rawHours = try? container.decodeIfPresent([String: OpeningHourDay].self, forKey: .opening_hours) {
            self.opening_hours = rawHours
        } else {
            self.opening_hours = nil
        }
    }
}

struct OpeningHourDay: Codable, Equatable {
    let open: String?
    let close: String?
    let isClosed: Bool?
}

struct Reservation: Codable, Identifiable {
    let id: String
    let restaurant_id: String
    let customer_name: String
    let customer_email: String
    let customer_phone: String?
    let party_size: Int
    let reservation_date: String // YYYY-MM-DD
    let reservation_time: String // HH:MM:SS
    let status: String
    let special_requests: String?
    let created_at: String?
    
    // Join - mapped via decoder
    let owner: Profile?
    
    // Computed helper properties to maintain compatibility with existing screens
    var customer: Profile? {
        return Profile(
            id: "",
            email: customer_email,
            full_name: customer_name,
            avatar_url: nil,
            role: "customer",
            roles: ["customer"],
            restaurant_name: nil,
            logo_url: nil,
            cuisine: nil,
            address: nil,
            phone: customer_phone,
            city: nil,
            pincode: nil,
            fssai_number: nil,
            opening_hours: nil,
            bio: nil
        )
    }
    
    var guest_count: Int {
        return party_size
    }
    
    var restaurant_owner_id: String {
        return restaurant_id
    }
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
        let token = try await getValidAccessTokenOrRefresh()
        
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
    
    func updateProfile(role: String, roles: [String]?, fullName: String?, restaurantName: String?, logoURL: String?, cuisine: String?, address: String?, phone: String?, city: String?, pincode: String?, fssai: String?, openingHours: String?, bio: String?) async throws {
        let token = try await getValidAccessTokenOrRefresh()
        guard let userId = currentUser?.id else { throw URLError(.userAuthenticationRequired) }
        
        let url = SupabaseConfig.databaseURL.appendingPathComponent("profiles")
             .appending(queryItems: [URLQueryItem(name: "id", value: "eq.\(userId)")])
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = ["role": role]
        if let roles = roles { body["roles"] = roles }
        if let fName = fullName { body["full_name"] = fName }
        if let rName = restaurantName { body["restaurant_name"] = rName }
        if let lURL = logoURL { body["logo_url"] = lURL }
        if let c = cuisine { body["cuisine"] = c }
        if let a = address { body["address"] = a }
        if let p = phone { body["phone"] = p }
        if let ci = city { body["city"] = ci }
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

    func completeOwnerOnboarding(restaurantName: String, cuisine: String, address: String, phone: String, city: String, pincode: String, logoURL: String, fssai: String, ownerName: String) async throws {
        let token = try await getValidAccessTokenOrRefresh()
        guard let userId = currentUser?.id else { throw URLError(.userAuthenticationRequired) }
        
        // 1. GET checking if restaurant row already exists
        let checkURL = SupabaseConfig.databaseURL.appendingPathComponent("restaurants")
            .appending(queryItems: [URLQueryItem(name: "owner_id", value: "eq.\(userId)")])
        
        var checkRequest = URLRequest(url: checkURL)
        checkRequest.httpMethod = "GET"
        checkRequest.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        checkRequest.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        
        let (data, response) = try await URLSession.shared.data(for: checkRequest)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        struct TempRest: Decodable { let id: String }
        let existingRests = try? JSONDecoder().decode([TempRest].self, from: data)
        let isUpdate = existingRests != nil && !existingRests!.isEmpty
        
        // 2. Perform write to restaurants table (POST or PATCH)
        let url: URL
        let method: String
        if isUpdate {
            let restId = existingRests!.first!.id
            url = SupabaseConfig.databaseURL.appendingPathComponent("restaurants")
                .appending(queryItems: [URLQueryItem(name: "id", value: "eq.\(restId)")])
            method = "PATCH"
        } else {
            url = SupabaseConfig.databaseURL.appendingPathComponent("restaurants")
            method = "POST"
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [
            "name": restaurantName,
            "cuisine_type": cuisine,
            "address": address,
            "phone": phone,
            "city": city,
            "pincode": pincode,
            "logo_url": logoURL,
            "status": "active",
            "fssai_number": fssai,
            "onboarding_step": 4
        ]
        if !isUpdate {
            body["owner_id"] = userId
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (writeData, writeResponse) = try await URLSession.shared.data(for: request)
        guard let httpWriteResponse = writeResponse as? HTTPURLResponse, (200...299).contains(httpWriteResponse.statusCode) else {
            let errorBody = String(data: writeData, encoding: .utf8) ?? ""
            print("❌ completeOwnerOnboarding: restaurants write failed: \(errorBody)")
            throw URLError(.badServerResponse)
        }
        
        // 3. Fetch current profile to securely deduplicate roles array
        var profileRoles = ["customer"]
        do {
            let currentProfile = try await fetchProfile(userId: userId)
            profileRoles = currentProfile.roles ?? ["customer"]
        } catch {
            print("⚠️ completeOwnerOnboarding: profile check failed, using default roles")
        }
        if !profileRoles.contains("owner") {
            profileRoles.append("owner")
        }
        
        // 4. Update profiles table
        do {
            try await updateProfile(
                role: "owner",
                roles: profileRoles,
                fullName: ownerName,
                restaurantName: restaurantName,
                logoURL: logoURL,
                cuisine: cuisine,
                address: address,
                phone: phone,
                city: city,
                pincode: pincode,
                fssai: fssai,
                openingHours: nil,
                bio: nil
            )
        } catch {
            print("❌ completeOwnerOnboarding: profiles update failed: \(error.localizedDescription)")
            
            // Compensation Rollback
            if !isUpdate {
                print("🔄 completeOwnerOnboarding: rollback deleting inserted restaurant...")
                let deleteURL = SupabaseConfig.databaseURL.appendingPathComponent("restaurants")
                    .appending(queryItems: [URLQueryItem(name: "owner_id", value: "eq.\(userId)")])
                var deleteRequest = URLRequest(url: deleteURL)
                deleteRequest.httpMethod = "DELETE"
                deleteRequest.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                deleteRequest.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
                _ = try? await URLSession.shared.data(for: deleteRequest)
            }
            throw error
        }
        
        // 5. Update local userRole state
        await MainActor.run {
            self.userRole = "owner"
        }
    }

    func fetchOwnerRestaurant() async throws -> Restaurant {
        let token = try await getValidAccessTokenOrRefresh()
        guard let userId = currentUser?.id else { throw URLError(.userAuthenticationRequired) }
        
        // Fetch owner's restaurant (regardless of status active or draft to avoid resourceUnavailable dashboard crashes)
        let url = SupabaseConfig.databaseURL.appendingPathComponent("restaurants")
            .appending(queryItems: [
                URLQueryItem(name: "owner_id", value: "eq.\(userId)")
            ])
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            if let httpResponse = response as? HTTPURLResponse {
                let body = String(data: data, encoding: .utf8) ?? ""
                print("❌ fetchOwnerRestaurant failed with status \(httpResponse.statusCode): \(body)")
            }
            throw URLError(.badServerResponse)
        }
        
        let restaurants = try JSONDecoder().decode([Restaurant].self, from: data)
        guard let restaurant = restaurants.first else {
            throw URLError(.resourceUnavailable)
        }
        return restaurant
    }
    
    func updateRestaurant(
        name: String?,
        description: String?,
        cuisineType: String?,
        phone: String?,
        address: String?,
        city: String?,
        pincode: String?,
        logoUrl: String?,
        galleryUrls: [String]?,
        openingHours: [String: OpeningHourDay]?
    ) async throws {
        let token = try await getValidAccessTokenOrRefresh()
        guard let userId = currentUser?.id else { throw URLError(.userAuthenticationRequired) }
        
        // Find existing restaurant first to get its ID
        let checkURL = SupabaseConfig.databaseURL.appendingPathComponent("restaurants")
            .appending(queryItems: [URLQueryItem(name: "owner_id", value: "eq.\(userId)")])
        
        var checkRequest = URLRequest(url: checkURL)
        checkRequest.httpMethod = "GET"
        checkRequest.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        checkRequest.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        
        let (data, response) = try await URLSession.shared.data(for: checkRequest)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        struct TempRest: Decodable { let id: String }
        let existingRests = try? JSONDecoder().decode([TempRest].self, from: data)
        
        let url: URL
        let method: String
        
        if let existing = existingRests?.first {
            url = SupabaseConfig.databaseURL.appendingPathComponent("restaurants")
                .appending(queryItems: [URLQueryItem(name: "id", value: "eq.\(existing.id)")])
            method = "PATCH"
        } else {
            url = SupabaseConfig.databaseURL.appendingPathComponent("restaurants")
            method = "POST"
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [:]
        if method == "POST" {
            body["owner_id"] = userId
            body["status"] = "active"
        }
        if let name = name { body["name"] = name }
        if let description = description { body["description"] = description }
        if let cuisineType = cuisineType { body["cuisine_type"] = cuisineType }
        if let phone = phone { body["phone"] = phone }
        if let address = address { body["address"] = address }
        if let city = city { body["city"] = city }
        if let pincode = pincode { body["pincode"] = pincode }
        if let logoUrl = logoUrl { body["logo_url"] = logoUrl }
        if let galleryUrls = galleryUrls { body["gallery_urls"] = galleryUrls }
        if let openingHours = openingHours {
            if let encodedHours = try? JSONEncoder().encode(openingHours),
               let jsonHours = try? JSONSerialization.jsonObject(with: encodedHours, options: []) {
                body["opening_hours"] = jsonHours
            }
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (writeData, writeResponse) = try await URLSession.shared.data(for: request)
        guard let httpWriteResponse = writeResponse as? HTTPURLResponse, (200...299).contains(httpWriteResponse.statusCode) else {
            let errorBody = String(data: writeData, encoding: .utf8) ?? ""
            print("❌ updateRestaurant failed: \(errorBody)")
            throw URLError(.badServerResponse)
        }
        
        // Also update profiles table to keep in sync
        try await updateProfile(
            role: "owner",
            roles: nil,
            fullName: nil,
            restaurantName: name,
            logoURL: logoUrl,
            cuisine: cuisineType,
            address: address,
            phone: phone,
            city: city,
            pincode: pincode,
            fssai: nil,
            openingHours: nil,
            bio: description
        )
    }

    func softDeleteRestaurant() async throws {
        let token = try await getValidAccessTokenOrRefresh()
        guard let userId = currentUser?.id else { throw URLError(.userAuthenticationRequired) }
        
        // Find existing restaurant first to get its ID
        let checkURL = SupabaseConfig.databaseURL.appendingPathComponent("restaurants")
            .appending(queryItems: [URLQueryItem(name: "owner_id", value: "eq.\(userId)")])
        
        var checkRequest = URLRequest(url: checkURL)
        checkRequest.httpMethod = "GET"
        checkRequest.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        checkRequest.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        
        let (data, response) = try await URLSession.shared.data(for: checkRequest)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        struct TempRest: Decodable { let id: String }
        let existingRests = try? JSONDecoder().decode([TempRest].self, from: data)
        guard let existing = existingRests?.first else { return }
        
        let url = SupabaseConfig.databaseURL.appendingPathComponent("restaurants")
            .appending(queryItems: [
                URLQueryItem(name: "id", value: "eq.\(existing.id)"),
                URLQueryItem(name: "owner_id", value: "eq.\(userId)")
            ])
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let formatter = ISO8601DateFormatter()
        let dateString = formatter.string(from: Date())
        let body: [String: Any] = [
            "status": "deleted",
            "deleted_at": dateString
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (writeData, writeResponse) = try await URLSession.shared.data(for: request)
        guard let httpWriteResponse = writeResponse as? HTTPURLResponse, (200...299).contains(httpWriteResponse.statusCode) else {
            let errorBody = String(data: writeData, encoding: .utf8) ?? ""
            print("❌ softDeleteRestaurant failed: \(errorBody)")
            throw URLError(.badServerResponse)
        }
    }
    
    // MARK: - Reservations
    
    func createReservation(ownerId: String, guests: Int, date: Date, special: String?) async throws {
        let token = try await getValidAccessTokenOrRefresh()
        guard let userId = currentUser?.id else { throw URLError(.userAuthenticationRequired) }
        
        let profile = try? await fetchProfile(userId: userId)
        let customerName = profile?.full_name ?? currentUser?.email ?? "Guest"
        let customerEmail = currentUser?.email ?? ""
        let customerPhone = profile?.phone
        
        let url = SupabaseConfig.databaseURL.appendingPathComponent("reservations")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone.current
        let dateString = dateFormatter.string(from: date)
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        timeFormatter.timeZone = TimeZone.current
        let timeString = timeFormatter.string(from: date)
        
        var body: [String: Any] = [
            "restaurant_id": ownerId,
            "customer_name": customerName,
            "customer_email": customerEmail,
            "party_size": guests,
            "reservation_date": dateString,
            "reservation_time": timeString,
            "status": "pending"
        ]
        if let phone = customerPhone {
            body["customer_phone"] = phone
        }
        if let special = special, !special.isEmpty {
            body["special_requests"] = special
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            print("❌ createReservation failed with status \(httpResponse.statusCode): \(errorBody)")
            throw URLError(.badServerResponse)
        }
    }
    
    func fetchMyReservations() async throws -> [Reservation] {
        let token = try await getValidAccessTokenOrRefresh()
        guard let userId = currentUser?.id else { throw URLError(.userAuthenticationRequired) }
        guard let email = currentUser?.email else { throw URLError(.userAuthenticationRequired) }
        
        // Fetch reservations (safe fallback without profiles join due to database schema mismatch)
        let url = SupabaseConfig.databaseURL.appendingPathComponent("reservations")
            .appending(queryItems: [
                URLQueryItem(name: "customer_email", value: "eq.\(email)"),
                URLQueryItem(name: "order", value: "reservation_date.desc"),
                URLQueryItem(name: "select", value: "*")
            ])
            
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                if let httpResponse = response as? HTTPURLResponse {
                    let body = String(data: data, encoding: .utf8) ?? ""
                    print("⚠️ fetchMyReservations failed with status \(httpResponse.statusCode): \(body)")
                }
                return []
            }
            
            return try JSONDecoder().decode([Reservation].self, from: data)
        } catch {
            print("⚠️ fetchMyReservations failed with error: \(error.localizedDescription)")
            return []
        }
    }
    
    func fetchRestaurants() async throws -> [Restaurant] {
        let url = SupabaseConfig.databaseURL.appendingPathComponent("restaurants")
            .appending(queryItems: [URLQueryItem(name: "status", value: "eq.active")])
        
        // ✅ 15-second timeout + no cache to avoid stale data
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.httpMethod = "GET"
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        // ✅ Include auth token if available so RLS policies can allow the read
        if let token = try? await getValidAccessTokenOrRefresh() {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "<no body>"
            print("❌ fetchRestaurants failed [\(httpResponse.statusCode)]: \(errorBody)")
            throw URLError(.badServerResponse)
        }
        
        let restaurants = try JSONDecoder().decode([Restaurant].self, from: data)
        print("✅ fetchRestaurants: loaded \(restaurants.count) restaurants")
        return restaurants
    }

    func fetchOwnerReservations(startDate: Date? = nil) async throws -> [Reservation] {
        let token = try await getValidAccessTokenOrRefresh()
        guard let userId = currentUser?.id else { throw URLError(.userAuthenticationRequired) }
        
        // Fetch reservations (safe fallback without profiles join due to database schema mismatch)
        var queryItems = [
            URLQueryItem(name: "restaurant_id", value: "eq.\(userId)"),
            URLQueryItem(name: "order", value: "reservation_date.asc"),
            URLQueryItem(name: "select", value: "*")
        ]
        
        if let startDate = startDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            let dateString = formatter.string(from: startDate)
            queryItems.append(URLQueryItem(name: "reservation_date", value: "gte.\(dateString)"))
        }
        
        // Fetch reservations + customer profile
        let baseURL = SupabaseConfig.databaseURL.appendingPathComponent("reservations")
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true)
        components?.queryItems = queryItems
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
            
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                if let httpResponse = response as? HTTPURLResponse {
                    let body = String(data: data, encoding: .utf8) ?? ""
                    print("⚠️ fetchOwnerReservations failed with status \(httpResponse.statusCode): \(body)")
                }
                return []
            }
            
            return try JSONDecoder().decode([Reservation].self, from: data)
        } catch {
            print("⚠️ fetchOwnerReservations failed with error: \(error.localizedDescription)")
            return []
        }
    }
    
    func updateReservationStatus(id: String, status: String) async throws {
        let token = try await getValidAccessTokenOrRefresh()
        
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

// MARK: - Order Management

extension SupabaseManager {
    /// Create a new order with snapshot data (immutable prices and restaurant info)
    func createOrder(
        restaurantId: String,
        restaurantName: String,
        items: [OrderItem],
        subtotal: Double,
        tax: Double,
        total: Double,
        paymentMethod: PaymentMethod = .cash,
        notes: String? = nil
    ) async throws -> Order {
        let token = try await getValidAccessTokenOrRefresh()
        guard let customerId = currentUser?.id else {
            throw URLError(.userAuthenticationRequired)
        }
        
        let url = SupabaseConfig.databaseURL.appendingPathComponent("orders")
        
        // Build order payload with SNAPSHOT data
        let orderData: [String: Any] = [
            "customer_id": customerId,
            "restaurant_id": restaurantId,
            "restaurant_name": restaurantName,  // SNAPSHOT
            "status": OrderStatus.received.rawValue,
            "payment_method": paymentMethod.rawValue,
            "subtotal": subtotal,
            "tax": tax,
            "total": total,
            "special_notes": notes as Any,
            "customer_name": currentUser?.email as Any
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("return=representation", forHTTPHeaderField: "Prefer")
        
        request.httpBody = try JSONSerialization.data(withJSONObject: orderData)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        // Parse created order
        let orders = try JSONDecoder().decode([Order].self, from: data)
        guard let order = orders.first else {
            throw URLError(.cannotParseResponse)
        }
        
        print("✅ Order created successfully: \(order.id)")
        return order
    }
}
