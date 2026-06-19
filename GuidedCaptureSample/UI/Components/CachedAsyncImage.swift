import SwiftUI

/// A global shared URLCache to persist images across sessions
public let ImageCache = URLCache(memoryCapacity: 100 * 1024 * 1024, // 100 MB memory
                                  diskCapacity: 500 * 1024 * 1024,   // 500 MB disk
                                  diskPath: "cached_images")

public struct CachedAsyncImage<Content: View>: View {
    private let url: URL?
    private let scale: CGFloat
    private let transaction: Transaction
    private let content: (AsyncImagePhase) -> Content
    
    @State private var phase: AsyncImagePhase
    
    public init(url: URL?,
                scale: CGFloat = 1.0,
                transaction: Transaction = Transaction(),
                @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        self.url = url
        self.scale = scale
        self.transaction = transaction
        self.content = content
        
        self._phase = State(wrappedValue: .empty)
    }
    
    public var body: some View {
        content(phase)
            .task(id: url) {
                await loadImage()
            }
    }
    
    @MainActor
    private func loadImage() async {
        guard let url = url else {
            phase = .empty
            return
        }
        
        // 1. Check Cache
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
        if let cachedResponse = ImageCache.cachedResponse(for: request),
           let image = UIImage(data: cachedResponse.data) {
            phase = .success(Image(uiImage: image))
            return
        }
        
        // 2. Fetch Network
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                phase = .failure(URLError(.badServerResponse))
                return
            }
            
            if let image = UIImage(data: data) {
                // Store in cache manually in case headers lack cache-control
                let cachedData = CachedURLResponse(response: response, data: data)
                ImageCache.storeCachedResponse(cachedData, for: request)
                
                withAnimation(transaction.animation) {
                    phase = .success(Image(uiImage: image))
                }
            } else {
                phase = .failure(URLError(.cannotDecodeRawData))
            }
        } catch {
            if Task.isCancelled { return }
            phase = .failure(error)
        }
    }
}
