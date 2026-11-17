import SwiftUI
import Combine

struct UnifiedUploadItem: Identifiable {
    let id: String // dish id or session id
    let title: String
    let status: String // "uploading", "pending", "processing", "ready", "failed"
    let progress: Double?
    let timestamp: Date
}

struct UploadQueueView: View {
    let dishes: [Dish]
    let onRetry: ((Dish) -> Void)?
    
    @StateObject private var backgroundUploader = BackgroundUploader.shared
    @State private var localUploads: [[String: String]] = []
    
    let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    
    var unifiedItems: [UnifiedUploadItem] {
        var items: [UnifiedUploadItem] = []
        
        // 1. Add remote processing items
        let remoteProcessing = dishes.filter { 
            let s = $0.model_conversion_status ?? $0.generation_status ?? ""
            let isFinished = s == "ready" || s == "completed" || $0.model_glb_url != nil
            return (s == "pending" || s == "processing" || s == "failed" || s == "pending_upload") && !isFinished
        }
        
        // To handle 15-minute watchdog logic, check conversion_started_at
        for dish in remoteProcessing {
            // Check if it's currently uploading locally
            if let local = localUploads.first(where: { $0["dish_id"] == dish.id }),
               let sessionId = local["session_id"] {
                let activeProgress = backgroundUploader.activeUploads[sessionId]
                let state = local["upload_state"] ?? "uploading"
                
                // If state is still "uploading" but no active progress exists,
                // the upload likely just completed and UserDefaults hasn't been updated yet.
                // Treat as "processing" to avoid showing stale "Uploading 0%"
                let effectiveState: String
                if state == "uploading" && activeProgress == nil {
                    effectiveState = "processing"
                } else {
                    effectiveState = state
                }
                
                items.append(UnifiedUploadItem(
                    id: dish.id,
                    title: dish.name,
                    status: effectiveState == "failed" ? "failed_upload" : (effectiveState == "processing" ? "processing" : "uploading"),
                    progress: (effectiveState == "failed" || effectiveState == "processing") ? nil : activeProgress,
                    timestamp: Date()
                ))
            } else {
                var status = dish.model_conversion_status ?? dish.generation_status ?? ""
                
                // Watchdog UI Logic: If pending/processing for > 15 mins, treat as failed
                if (status == "pending" || status == "processing"),
                   let startedAtStr = dish.conversion_started_at,
                   let startedAt = ISO8601DateFormatter.parse(startedAtStr),
                   Date().timeIntervalSince(startedAt) > 15 * 60 {
                    status = "failed"
                }
                
                if status != "pending_upload" {
                    items.append(UnifiedUploadItem(
                        id: dish.id,
                        title: dish.name,
                        status: status,
                        progress: nil,
                        timestamp: Date()
                    ))
                }
            }
        }
        
        return items.sorted(by: { $0.timestamp > $1.timestamp })
    }
    
    var body: some View {
        let items = unifiedItems
        
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Upload Queue")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                
                VStack(spacing: 0) {
                    ForEach(items) { item in
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                // Icon
                                ZStack {
                                    Circle()
                                        .fill(colorForStatus(item.status).opacity(0.1))
                                        .frame(width: 36, height: 36)
                                    
                                    Image(systemName: iconForStatus(item.status))
                                        .font(.system(size: 14))
                                        .foregroundColor(colorForStatus(item.status))
                                        .rotationEffect(.degrees(item.status == "processing" || item.status == "uploading" ? 360 : 0))
                                        .animation(
                                            (item.status == "processing" || item.status == "uploading") ? 
                                            Animation.linear(duration: 2).repeatForever(autoreverses: false) : .default,
                                            value: item.status
                                        )
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                    
                                    Text(textForStatus(item.status, progress: item.progress))
                                        .font(.system(size: 12))
                                        .foregroundColor(colorForStatus(item.status))
                                }
                                
                                Spacer()
                                
                                if item.status == "failed" || item.status == "failed_upload", let onRetry = onRetry, let dish = dishes.first(where: { $0.id == item.id }) {
                                    Button(action: {
                                        onRetry(dish)
                                    }) {
                                        Text("Retry")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color(hex: "EF4444"))
                                            .cornerRadius(6)
                                    }
                                } else if item.status == "uploading" {
                                    if let p = item.progress {
                                        Text("\(Int(p * 100))%")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                }
                            }
                            .padding(16)
                            
                            if item.status == "uploading", let p = item.progress {
                                GeometryReader { geo in
                                    Rectangle()
                                        .fill(Color(hex: "3B82F6"))
                                        .frame(width: geo.size.width * CGFloat(p), height: 2)
                                        .animation(.linear, value: p)
                                }
                                .frame(height: 2)
                                .background(Color.white.opacity(0.05))
                            }
                            
                            if item.id != items.last?.id {
                                Divider()
                                    .background(Color.white.opacity(0.1))
                            }
                        }
                    }
                }
                .background(Color(hex: "1E293B"))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal, 16)
            }
            .onAppear {
                loadLocalUploads()
            }
            .onReceive(timer) { _ in
                loadLocalUploads()
            }
        }
    }
    
    private func loadLocalUploads() {
        if let pendingList = UserDefaults.standard.array(forKey: "pending_dish_uploads") as? [[String: String]] {
            localUploads = pendingList
        }
    }
    
    private func iconForStatus(_ status: String) -> String {
        switch status {
        case "uploading": return "arrow.up.circle.fill"
        case "pending", "processing": return "arrow.triangle.2.circlepath"
        case "failed", "failed_upload": return "exclamationmark.triangle.fill"
        case "ready", "completed": return "checkmark.circle.fill"
        default: return "ellipsis.circle.fill"
        }
    }
    
    private func colorForStatus(_ status: String) -> Color {
        switch status {
        case "uploading": return Color(hex: "3B82F6") // Blue
        case "pending", "processing": return Color(hex: "F59E0B") // Orange
        case "failed", "failed_upload": return Color(hex: "EF4444") // Red
        case "ready", "completed": return Color(hex: "10B981") // Green
        default: return .gray
        }
    }
    
    private func textForStatus(_ status: String, progress: Double?) -> String {
        switch status {
        case "uploading": return "Uploading 3D Model..."
        case "pending": return "Waiting in Queue..."
        case "processing": return "Converting to GLB..."
        case "failed": return "Conversion Failed"
        case "failed_upload": return "Upload Failed"
        case "ready", "completed": return "Completed"
        default: return "Unknown State"
        }
    }
}
