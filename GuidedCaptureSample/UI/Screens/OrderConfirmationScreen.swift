//
//  OrderConfirmationScreen.swift
//  GuidedCaptureSample
//

import SwiftUI

struct OrderConfirmationScreen: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var cartManager = CartManager.shared

    let restaurantId: String
    let customerName: String
    let customerPhone: String        // Already in E.164 format
    let specialNotes: String?
    let paymentMethod: PaymentMethod
    var onOrderPlaced: (String) -> Void   // Callback with order ID
    var onDismiss: () -> Void             // Called when user taps "Back to Menu"

    // UI State
    @State private var isPlacingOrder = false
    @State private var placedOrder: Order? = nil
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showEditSheet = false

    // MARK: - Body

    var body: some View {
        Group {
            if let order = placedOrder {
                successView(order: order)
            } else {
                confirmView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.background.ignoresSafeArea())
        .alert("Order Failed", isPresented: $showError) {
            Button("OK", role: .cancel) {
                isPlacingOrder = false
            }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Confirm View

    private var confirmView: some View {
        VStack(spacing: 0) {

            // ── Header ─────────────────────────────────────────────────
            HStack {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.05))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                }
                Spacer()
                Text("Confirm Order")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Color.clear.frame(width: 40)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Color(hex: "1E293B")
                    .ignoresSafeArea(.container, edges: .top)
            )
            .overlay(
                Rectangle().frame(height: 1).foregroundColor(Color.white.opacity(0.08)),
                alignment: .bottom
            )

            // ── Scrollable Cards ──────────────────────────────────────────
            // ScrollView fills all remaining space between header and button
            // because it is the only flexible child in this VStack.
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {

                    // Your Details
                    infoCard(title: "Your Details") {
                        DetailRow(label: "Name",  value: customerName)
                        DetailRow(label: "Phone", value: customerPhone)
                        if let notes = specialNotes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Special Instructions")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.6))
                                Text(notes)
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)
                            }
                        }
                    }

                    // Payment
                    infoCard(title: "Payment") {
                        HStack(spacing: 12) {
                            Image(systemName: paymentMethod.iconName)
                                .foregroundColor(Color(hex: "3B82F6"))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(paymentMethod.displayName)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("Pay when you pick up")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                    }

                    // Order Summary
                    infoCard(title: "Order Summary") {
                        ForEach(cartManager.items) { item in
                            HStack {
                                Text("\(item.quantity)×")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(hex: "3B82F6"))
                                    .frame(width: 36, alignment: .leading)
                                Text(item.name)
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)
                                Spacer()
                                Text(String(format: "$%.2f", item.totalPrice))
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)
                            }
                        }
                        Divider().background(Color.white.opacity(0.1)).padding(.vertical, 6)
                        HStack {
                            Text("Subtotal").foregroundColor(.white.opacity(0.6))
                            Spacer()
                            Text(String(format: "$%.2f", cartManager.subtotal)).foregroundColor(.white)
                        }.font(.system(size: 14))
                        HStack {
                            Text("Tax (5%)").foregroundColor(.white.opacity(0.6))
                            Spacer()
                            Text(String(format: "$%.2f", cartManager.tax)).foregroundColor(.white)
                        }.font(.system(size: 14))
                        Divider().background(Color.white.opacity(0.1)).padding(.vertical, 4)
                        HStack {
                            Text("Total").font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                            Spacer()
                            Text(String(format: "$%.2f", cartManager.total))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Color(hex: "3B82F6"))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 20)
            }

            // ── Place Order Button — pinned to the bottom ─────────────────
            VStack(spacing: 0) {
                // Subtle gradient fade from transparent → background
                LinearGradient(
                    colors: [Theme.background.opacity(0), Theme.background],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 24)

                Button(action: placeOrder) {
                    HStack {
                        if isPlacingOrder {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .padding(.trailing, 6)
                            Text("Placing Order...")
                                .font(.system(size: 17, weight: .bold))
                        } else {
                            Text("Place Order")
                                .font(.system(size: 17, weight: .bold))
                            Spacer()
                            Text(String(format: "$%.2f", cartManager.total))
                                .font(.system(size: 17, weight: .bold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 18)
                    .background(
                        isPlacingOrder
                            ? LinearGradient(colors: [.gray, .gray], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [Color(hex: "3B82F6"), Color(hex: "2563EB")], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(16)
                    .shadow(color: Color(hex: "3B82F6").opacity(isPlacingOrder ? 0 : 0.4), radius: 12, x: 0, y: 6)
                }
                .disabled(isPlacingOrder)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                .padding(.top, 4)
                .background(Theme.background)
            }
        }
    }

    // MARK: - Success View

    private func successView(order: Order) -> some View {
        VStack(spacing: 0) {
            Spacer()

            // Checkmark + Order ID
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [Color(hex: "10B981"), Color(hex: "059669")], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 100, height: 100)
                    Image(systemName: "checkmark")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(.white)
                }
                .shadow(color: Color(hex: "10B981").opacity(0.5), radius: 20, x: 0, y: 10)

                Text("Order Placed!")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)

                Text("Order ID")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(1.5)

                Text(order.displayOrderNumber)
                    .font(.system(size: 42, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "3B82F6"))
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Color(hex: "1E293B"))
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "3B82F6").opacity(0.3), lineWidth: 1))

                Text("We've received your order.\nTrack updates below 👇")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 32)

            Spacer()

            // Action Buttons
            VStack(spacing: 12) {
                Button(action: { onOrderPlaced(order.id) }) {
                    Label("Track My Order", systemImage: "location.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(LinearGradient(colors: [Color(hex: "3B82F6"), Color(hex: "2563EB")], startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(16)
                        .shadow(color: Color(hex: "3B82F6").opacity(0.4), radius: 12, x: 0, y: 6)
                }

                Button(action: { onDismiss() }) {
                    Text("Back to Menu")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white.opacity(0.07))
                        .cornerRadius(16)
                }

                // Edit contact details — only when status is still .received
                if order.status == .received {
                    Button(action: { showEditSheet = true }) {
                        Label("Edit contact details", systemImage: "pencil")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func infoCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(hex: "1E293B"))
        .cornerRadius(16)
    }

    // MARK: - Place Order

    private func placeOrder() {
        guard !isPlacingOrder else { return }

        guard !cartManager.items.isEmpty else {
            errorMessage = "Your cart is empty."
            showError = true
            return
        }

        isPlacingOrder = true

        Task {
            do {
                let order = try await SupabaseManager.shared.createOrder(
                    restaurantId: restaurantId,
                    items: cartManager.items,
                    paymentMethod: paymentMethod,
                    specialNotes: specialNotes,
                    customerName: customerName,
                    customerPhone: customerPhone
                )
                await MainActor.run {
                    cartManager.clear()
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        placedOrder = order
                    }
                }
            } catch {
                await MainActor.run {
                    isPlacingOrder = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}
