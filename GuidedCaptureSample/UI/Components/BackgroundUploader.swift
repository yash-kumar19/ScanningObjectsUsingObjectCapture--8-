import Foundation
import Combine

struct UploadTaskInfo: Codable {
    let dishId: String
    let fileURLPath: String
    let intendedStatus: String
    let sessionId: String
    let bucket: String
    let objectPath: String
}

class BackgroundUploader: NSObject, ObservableObject {
    static let shared = BackgroundUploader()
    
    @Published var activeUploads: [String: Double] = [:] // session_id -> progress
    
    private var session: URLSession!
    
    override init() {
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: "com.see3dine.upload")
        config.waitsForConnectivity = true
        config.allowsCellularAccess = true
        config.isDiscretionary = false
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    func startUpload(fileURL: URL, name: String, dishId: String, intendedStatus: String, sessionId: String, token: String) throws {
        let bucket = "models"
        let objectPath = name
        
        let url = SupabaseConfig.storageURL
            .appendingPathComponent("object")
            .appendingPathComponent(bucket)
            .appendingPathComponent(objectPath)
            
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.addValue("true", forHTTPHeaderField: "x-upsert")
        
        let taskInfo = UploadTaskInfo(dishId: dishId, fileURLPath: fileURL.path, intendedStatus: intendedStatus, sessionId: sessionId, bucket: bucket, objectPath: objectPath)
        let encoder = JSONEncoder()
        let taskDescription = String(data: try encoder.encode(taskInfo), encoding: .utf8)!
        
        let task = session.uploadTask(with: request, fromFile: fileURL)
        task.taskDescription = taskDescription
        task.resume()
        
        DispatchQueue.main.async {
            self.activeUploads[sessionId] = 0.0
        }
    }
}

extension BackgroundUploader: URLSessionTaskDelegate, URLSessionDataDelegate {
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard let desc = task.taskDescription,
              let data = desc.data(using: .utf8),
              let taskInfo = try? JSONDecoder().decode(UploadTaskInfo.self, from: data) else { return }
        
        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        
        DispatchQueue.main.async {
            self.activeUploads[taskInfo.sessionId] = progress
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let desc = task.taskDescription,
              let data = desc.data(using: .utf8),
              let taskInfo = try? JSONDecoder().decode(UploadTaskInfo.self, from: data) else { return }
        
        if let error = error {
            print("❌ Background upload failed for \(taskInfo.sessionId): \(error)")
            updateLocalQueueState(sessionId: taskInfo.sessionId, state: "failed")
            DispatchQueue.main.async {
                self.activeUploads.removeValue(forKey: taskInfo.sessionId)
            }
            return
        }
        
        let httpResponse = task.response as? HTTPURLResponse
        if let status = httpResponse?.statusCode, (200...299).contains(status) {
            let publicURL = "\(SupabaseConfig.url)/storage/v1/object/public/\(taskInfo.bucket)/\(taskInfo.objectPath)"
            
            // ⚠️ IMPORTANT: Update UserDefaults state BEFORE removing from activeUploads
            // This prevents a race where the UI sees no activeUpload entry + old "uploading" state
            updateLocalQueueState(sessionId: taskInfo.sessionId, state: "processing")
            
            // Now safe to remove from activeUploads — UserDefaults already shows "processing"
            DispatchQueue.main.async {
                self.activeUploads.removeValue(forKey: taskInfo.sessionId)
            }
            
            Task {
                do {
                    try await SupabaseManager.shared.updateDishPostBackgroundUpload(
                        dishId: taskInfo.dishId,
                        modelURL: publicURL,
                        intendedStatus: taskInfo.intendedStatus
                    )
                    
                    // Trigger edge function to generate GLB for web & Android AR
                    await SupabaseManager.shared.triggerModelConversion(
                        dishId: taskInfo.dishId,
                        modelURL: publicURL
                    )
                    
                    let fileURL = URL(fileURLWithPath: taskInfo.fileURLPath)
                    try? FileManager.default.removeItem(at: fileURL)
                    
                    // Also delete imagesFolder explicitly as per cleanup strategy
                    let imagesURL = fileURL.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Images")
                    try? FileManager.default.removeItem(at: imagesURL)
                    
                    // Clean up local uploader queue from UserDefaults since DB update succeeded
                    self.removeFromLocalQueue(sessionId: taskInfo.sessionId)
                    
                    print("✅ Background upload and DB update complete for \(taskInfo.dishId)")
                    
                    // Post notification to reload menu screen on main thread
                    await MainActor.run {
                        NotificationCenter.default.post(name: Notification.Name("supabaseDataDidUpdate"), object: nil)
                    }
                } catch {
                    print("❌ Failed to update DB after background upload: \(error)")
                    updateLocalQueueState(sessionId: taskInfo.sessionId, state: "failed_db")
                    
                    await MainActor.run {
                        NotificationCenter.default.post(name: Notification.Name("supabaseDataDidUpdate"), object: nil)
                    }
                }
            }
        } else {
             print("❌ Background upload failed with HTTP status: \(httpResponse?.statusCode ?? -1)")
             updateLocalQueueState(sessionId: taskInfo.sessionId, state: "failed")
             
             DispatchQueue.main.async {
                 self.activeUploads.removeValue(forKey: taskInfo.sessionId)
                 NotificationCenter.default.post(name: Notification.Name("supabaseDataDidUpdate"), object: nil)
             }
        }
    }
    
    private func updateLocalQueueState(sessionId: String, state: String) {
        let key = "pending_dish_uploads"
        guard var pendingList = UserDefaults.standard.array(forKey: key) as? [[String: String]] else { return }
        if let index = pendingList.firstIndex(where: { $0["session_id"] == sessionId }) {
            pendingList[index]["upload_state"] = state
            UserDefaults.standard.set(pendingList, forKey: key)
        }
    }
    
    private func removeFromLocalQueue(sessionId: String) {
        let key = "pending_dish_uploads"
        guard var pendingList = UserDefaults.standard.array(forKey: key) as? [[String: String]] else { return }
        pendingList.removeAll { $0["session_id"] == sessionId }
        UserDefaults.standard.set(pendingList, forKey: key)
    }
}
