import Foundation
import SwiftUI

/// Utility for downloading and caching 3D models from remote URLs
@MainActor
class ModelDownloader: ObservableObject {
    @Published var downloadProgress: Double = 0
    @Published var isDownloading: Bool = false
    @Published var error: String?
    
    private let cacheDirectory: URL
    
    // 🔥 CRITICAL: Custom URLSession for large USDZ files
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        
        // Extended timeouts for large files from Supabase CDN
        config.timeoutIntervalForRequest = 120  // 2 minutes per request
        config.timeoutIntervalForResource = 300 // 5 minutes total
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.allowsExpensiveNetworkAccess = true
        config.allowsConstrainedNetworkAccess = true
        
        return URLSession(configuration: config)
    }()
    
    init() {
        // Create cache directory in Documents/ModelCache
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDirectory = documentsPath.appendingPathComponent("ModelCache", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    /// Downloads a model from a remote URL and returns the local cached file URL
    /// - Parameter remoteURL: The HTTPS URL of the model in Supabase storage
    /// - Returns: Local file URL of the cached model
    func downloadModel(from remoteURL: URL) async throws -> URL {
        print("🔍 [ModelDownloader] Starting download process")
        print("🔍 [ModelDownloader] Remote URL: \(remoteURL.absoluteString)")
        print("🔍 [ModelDownloader] URL scheme: \(remoteURL.scheme ?? "nil")")
        print("🔍 [ModelDownloader] URL host: \(remoteURL.host ?? "nil")")
        print("🔍 [ModelDownloader] URL path: \(remoteURL.path)")
        
        // Generate cache filename from remote URL
        let filename = cacheFilename(for: remoteURL)
        let localURL = cacheDirectory.appendingPathComponent(filename)
        print("🔍 [ModelDownloader] Cache filename: \(filename)")
        print("🔍 [ModelDownloader] Local cache path: \(localURL.path)")
        
        // Check if already cached
        if FileManager.default.fileExists(atPath: localURL.path) {
            print("✅ Model already cached at: \(localURL.path)")
            return localURL
        }
        
        print("📥 Downloading model from: \(remoteURL.absoluteString)")
        
        await MainActor.run {
            isDownloading = true
            downloadProgress = 0
            error = nil
        }
        
        do {
            print("🔍 [ModelDownloader] Starting URLSession download...")
            
            // Download the file using custom session with extended timeouts
            let (tempURL, response) = try await session.download(from: remoteURL)
            
            print("🔍 [ModelDownloader] Download completed, checking response...")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [ModelDownloader] Response is not HTTPURLResponse")
                throw ModelDownloadError.invalidResponse
            }
            
            print("🔍 [ModelDownloader] HTTP Status Code: \(httpResponse.statusCode)")
            print("🔍 [ModelDownloader] Response headers: \(httpResponse.allHeaderFields)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ [ModelDownloader] Invalid status code: \(httpResponse.statusCode)")
                throw ModelDownloadError.invalidResponse
            }
            
            // Check file size before moving
            let attributes = try FileManager.default.attributesOfItem(atPath: tempURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            print("📦 Downloaded USDZ size: \(fileSize) bytes")
            
            if fileSize == 0 {
                print("❌ [ModelDownloader] Downloaded file is empty!")
                throw ModelDownloadError.fileNotFound
            }
            
            // Move to cache directory
            print("🔍 [ModelDownloader] Moving file to cache directory...")
            try FileManager.default.moveItem(at: tempURL, to: localURL)
            
            await MainActor.run {
                isDownloading = false
                downloadProgress = 1.0
            }
            
            print("✅ Model downloaded and cached at: \(localURL.path)")
            return localURL
            
        } catch {
            print("❌ [ModelDownloader] Download failed with error: \(error)")
            print("❌ [ModelDownloader] Error type: \(type(of: error))")
            print("❌ [ModelDownloader] Error description: \(error.localizedDescription)")
            
            if let urlError = error as? URLError {
                print("❌ [ModelDownloader] URLError code: \(urlError.code.rawValue)")
                print("❌ [ModelDownloader] URLError description: \(urlError.localizedDescription)")
            }
            
            await MainActor.run {
                isDownloading = false
                self.error = error.localizedDescription
            }
            throw error
        }
    }
    
    /// Generates a cache filename from a remote URL
    private func cacheFilename(for url: URL) -> String {
        // Use the last path component (filename) from the URL
        // Supabase URLs typically end with: /storage/v1/object/public/models/{uuid}.usdz
        let filename = url.lastPathComponent
        
        // If it's a valid USDZ filename, use it
        if filename.hasSuffix(".usdz") || filename.hasSuffix(".USDZ") {
            return filename
        }
        
        // Otherwise, create a hash-based filename
        let hash = abs(url.absoluteString.hashValue)
        return "\(hash).usdz"
    }
    
    /// Clears all cached models
    func clearCache() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        print("🗑️ Model cache cleared")
    }
}

enum ModelDownloadError: LocalizedError {
    case invalidResponse
    case fileNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Server returned an invalid response"
        case .fileNotFound:
            return "Model file not found"
        }
    }
}
