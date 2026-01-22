import SwiftUI

/// Sheet view that handles downloading and previewing 3D models
struct ModelPreviewSheet: View {
    let modelURL: URL?
    let onDismiss: () -> Void
    
    @StateObject private var downloader = ModelDownloader()
    @State private var localModelURL: URL?
    @State private var downloadError: String?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let localURL = localModelURL {
                // Show the model using QuickLook
                ZStack(alignment: .topTrailing) {
                    ModelView(modelFile: localURL, endCaptureCallback: onDismiss)
                        .ignoresSafeArea()
                    
                    // Close Button
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                    .padding(24)
                }
            } else if downloader.isDownloading {
                // Show download progress
                VStack(spacing: 20) {
                    ProgressView(value: downloader.downloadProgress)
                        .progressViewStyle(.linear)
                        .tint(Color(hex: "3B82F6"))
                        .frame(width: 200)
                    
                    Text("Downloading model...")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("\(Int(downloader.downloadProgress * 100))%")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Button(action: onDismiss) {
                        Text("Cancel")
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color(hex: "1E293B"))
                            .cornerRadius(12)
                    }
                }
            } else if let error = downloadError {
                // Show error
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.yellow)
                    
                    Text("Download Failed")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button(action: onDismiss) {
                        Text("Close")
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color(hex: "3B82F6"))
                            .cornerRadius(12)
                    }
                }
            }
        }
        .onAppear {
            print("🔍 ModelPreviewSheet.onAppear")
            print("🔍 modelURL at onAppear: \(modelURL?.absoluteString ?? "nil")")
        }
        .task {
            await downloadModelIfNeeded()
        }
    }
    
    private func downloadModelIfNeeded() async {
        print("🔍 ModelPreviewSheet.downloadModelIfNeeded() called")
        print("🔍 Received modelURL: \(modelURL?.absoluteString ?? "nil")")
        
        guard let url = modelURL else {
            print("❌ No model URL provided")
            downloadError = "No model URL provided"
            return
        }
        
        // If it's already a local file URL, use it directly
        if url.isFileURL {
            localModelURL = url
            return
        }
        
        // Otherwise, download from remote URL
        do {
            let localURL = try await downloader.downloadModel(from: url)
            
            // 🔥 Give filesystem a moment to settle before Quick Look
            try await Task.sleep(nanoseconds: 300_000_000) // 0.3s
            
            await MainActor.run {
                localModelURL = localURL
            }
        } catch {
            await MainActor.run {
                downloadError = error.localizedDescription
            }
        }
    }
}
