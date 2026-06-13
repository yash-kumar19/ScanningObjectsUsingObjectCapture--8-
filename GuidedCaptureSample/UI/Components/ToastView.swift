//
//  ToastView.swift
//  GuidedCaptureSample
//
//  Created by Antigravity on 2026-02-16.
//

import SwiftUI

/// Global toast notification view
/// Displays success messages at the top of the screen
struct ToastView: View {
    @ObservedObject var manager: ToastManager
    
    var body: some View {
        VStack {
            if manager.isShowing, let message = manager.message {
                HStack(spacing: 12) {
                    // Checkmark icon
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    
                    // Message text
                    Text(message)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    // Close button
                    Button(action: {
                        manager.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    Color(hex: "10b981")
                        .opacity(0.95)
                )
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            Spacer()
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: manager.isShowing)
    }
}

