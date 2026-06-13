import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRMenuView: View {
    let restaurantId: String
    let restaurantName: String
    let menuURL: String
    var onDismiss: () -> Void
    
    @State private var qrImage: UIImage?
    @State private var showSaveSuccess = false
    @Environment(\.dismiss) private var dismiss
    
    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    
                    // MARK: - Header Info
                    VStack(spacing: 8) {
                        Text(restaurantName)
                            .font(.title2)
                            .bold()
                            .multilineTextAlignment(.center)
                        
                        Text("Scan to view menu")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // MARK: - QR Code Display
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white)
                            .shadow(radius: 5)
                            .frame(width: 280, height: 280)
                        
                        if let image = qrImage {
                            Image(uiImage: image)
                                .resizable()
                                .interpolation(.none)
                                .scaledToFit()
                                .frame(width: 240, height: 240)
                        } else {
                            ProgressView()
                                .frame(width: 240, height: 240)
                        }
                    }
                    
                    // MARK: - Open Menu Check
                    Link(destination: URL(string: menuURL)!) {
                        HStack {
                            Text("Open Menu in Browser")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.headline)
                        .foregroundColor(.blue)
                    }
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // MARK: - Action Buttons
                    VStack(spacing: 16) {
                        
                        // Share Button
                        ShareLink(item: URL(string: menuURL)!) {
                            Label("Share Menu Link", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                        }
                        
                        // Copy Link Button
                        Button {
                            UIPasteboard.general.string = menuURL
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                        } label: {
                            Label("Copy Link", systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                        }
                        
                        // Save Image Button
                        Button {
                            saveImage()
                        } label: {
                            Label(showSaveSuccess ? "Saved to Photos" : "Save QR Image", 
                                  systemImage: showSaveSuccess ? "checkmark" : "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(showSaveSuccess ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
                                .foregroundColor(showSaveSuccess ? .green : .accentColor)
                                .cornerRadius(12)
                        }
                        .disabled(qrImage == nil)
                    }
                    .padding(.horizontal, 40)
                }
                .padding()
            }
            .navigationTitle("Menu QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
            .onAppear {
                generateQR()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func generateQR() {
        // Caching: don't regenerate if we already have it
        guard qrImage == nil else { return }
        
        let data = Data(menuURL.utf8)
        filter.setValue(data, forKey: "inputMessage")
        
        if let outputImage = filter.outputImage {
            // Scale up the image for better quality
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)
            
            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                self.qrImage = UIImage(cgImage: cgImage)
            }
        }
    }
    
    private func saveImage() {
        guard let image = qrImage else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // UI Feedback
        withAnimation {
            showSaveSuccess = true
        }
        
        // Reset state after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showSaveSuccess = false
            }
        }
    }
}

// MARK: - Preview
#Preview {
    QRMenuView(
        restaurantId: "123-demo",
        restaurantName: "The Tasty Burger",
        menuURL: "https://example.com/menu/123",
        onDismiss: {}
    )
}
