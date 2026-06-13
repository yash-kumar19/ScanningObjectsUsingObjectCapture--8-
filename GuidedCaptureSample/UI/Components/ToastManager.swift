//
//  ToastManager.swift
//  GuidedCaptureSample
//
//  Created by Antigravity on 2026-02-16.
//

import Foundation
import SwiftUI

/// Global toast notification manager
/// Usage: ToastManager.shared.show("Item added to cart")
class ToastManager: ObservableObject {
    static let shared = ToastManager()
    
    @Published var message: String?
    @Published var isShowing: Bool = false
    
    private var dismissTask: Task<Void, Never>?
    
    private init() {}
    
    /// Show a toast notification with auto-dismiss after 2 seconds
    /// - Parameter message: The message to display
    @MainActor
    func show(_ message: String) {
        // Cancel previous dismiss task
        dismissTask?.cancel()
        
        // If a toast is already showing, reset it first
        if isShowing {
            isShowing = false
            // Small delay to let the animation reset
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                showToast(message: message)
            }
        } else {
            showToast(message: message)
        }
    }
    
    @MainActor
    private func showToast(message: String) {
        self.message = message
        withAnimation(.easeOut(duration: 0.3)) {
            isShowing = true
        }
        
        // Auto-dismiss after 2 seconds
        dismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation(.easeIn(duration: 0.3)) {
                isShowing = false
            }
        }
    }
    
    /// Manually dismiss the toast
    @MainActor
    func dismiss() {
        dismissTask?.cancel()
        withAnimation(.easeIn(duration: 0.3)) {
            isShowing = false
        }
    }
}
