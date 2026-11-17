import Foundation
import SwiftUI

/// Utility for downloading and caching 3D models from remote URLs
@MainActor
class ModelDownloader: NSObject, ObservableObject, URLSessionDownloadDelegate {
    @Published var downloadProgress: Double = 0
    @Published var isDownloading: Bool = false
    @Published var error: String?
    
    private let cacheDirectory: URL
    private var activeContinuation: CheckedContinuation<URL, Error>?
    private var activeDestinationURL: URL?
    
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
        
        return URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }()
    
    override init() {
        // Create cache directory in Documents/ModelCache
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDirectory = documentsPath.appendingPathComponent("ModelCache", isDirectory: true)
        
        super.init()
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        cleanupOldModels()
    }
    
    private func cleanupOldModels() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            let fileManager = FileManager.default
            let expirationDate = Date().addingTimeInterval(-7 * 24 * 60 * 60)
            
            do {
                let files = try fileManager.contentsOfDirectory(at: self.cacheDirectory, includingPropertiesForKeys: [.creationDateKey])
                for file in files {
                    if let attrs = try? fileManager.attributesOfItem(atPath: file.path),
                        let creationDate = attrs[.creationDate] as? Date,
                        creationDate < expirationDate {
                        try? fileManager.removeItem(at: file)
                        print("🗑️ Removed old cached model: \(file.lastPathComponent)")
                    }
                }
            } catch {
                print("⚠️ Failed to cleanup old models: \(error)")
            }
        }
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
            activeDestinationURL = localURL
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            activeContinuation = continuation
            let task = session.downloadTask(with: remoteURL)
            task.resume()
        }
    }
    
    /// Generates a cache filename from a remote URL
    nonisolated private func cacheFilename(for url: URL) -> String {
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
    
    // MARK: - URLSessionDownloadDelegate
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        Task { @MainActor in
            if totalBytesExpectedToWrite > 0 {
                self.downloadProgress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            }
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let remoteURL = downloadTask.originalRequest?.url else {
            Task { @MainActor in
                self.activeContinuation?.resume(throwing: ModelDownloadError.fileNotFound)
                self.activeContinuation = nil
                self.isDownloading = false
            }
            return
        }
        
        let filename = cacheFilename(for: remoteURL)
        let destinationURL = cacheDirectory.appendingPathComponent(filename)
        
        do {
            try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try? FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: location, to: destinationURL)
            
            Task { @MainActor in
                self.activeContinuation?.resume(returning: destinationURL)
                self.activeContinuation = nil
                self.isDownloading = false
            }
        } catch {
            print("❌ [ModelDownloader] Synchronous move failed: \(error)")
            Task { @MainActor in
                self.activeContinuation?.resume(throwing: error)
                self.activeContinuation = nil
                self.isDownloading = false
            }
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        Task { @MainActor in
            if let error = error {
                self.activeContinuation?.resume(throwing: error)
                self.activeContinuation = nil
                self.isDownloading = false
                self.error = error.localizedDescription
            }
        }
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
