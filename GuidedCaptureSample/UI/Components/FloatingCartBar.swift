//
//  FloatingCartBar.swift
//  GuidedCaptureSample
//
//  Created by Antigravity on 2026-01-30.
//

import SwiftUI

struct FloatingCartBar: View {
    @ObservedObject var cartManager: CartManager
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Cart Icon with Badge
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "cart.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                    
                    if cartManager.itemCount > 0 {
                        Text("\(cartManager.itemCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(Color.red)
                            .clipShape(Circle())
                            .offset(x: 8, y: -8)
                    }
                }
                .frame(width: 40, height: 40)
                
                // Cart Info
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(cartManager.itemCount) Item\(cartManager.itemCount == 1 ? "" : "s")")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(String(format: "$%.2f", cartManager.total))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                // View Cart Button
                Text("View Cart")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Color.white.opacity(0.2)
                    )
                    .cornerRadius(12)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [
                        Color(hex: "3B82F6"),
                        Color(hex: "2563EB")
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: Color(hex: "3B82F6").opacity(0.4), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .opacity(cartManager.isEmpty ? 0 : 1)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: cartManager.isEmpty)
    }
}
