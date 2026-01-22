import SwiftUI

struct BookingSheet: View {
    let ownerId: String
    let restaurantName: String
    var onDismiss: () -> Void
    var onSuccess: () -> Void
    
    @Binding var isPresented: Bool
    
    @State private var guestCount = 2
    @State private var selectedDate = Date()
    @State private var specialRequest = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            List {
                SwiftUI.Section(header: Text("Details")) {
                    DatePicker("Date & Time", selection: $selectedDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    
                    Stepper("Guests: \(guestCount)", value: $guestCount, in: 1...20)
                }
                
                SwiftUI.Section(header: Text("Special Request")) {
                    TextField("Any allergies or special occasions?", text: $specialRequest)
                }
                
                if let error = errorMessage {
                    SwiftUI.Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                SwiftUI.Section {
                    Button(action: submitBooking) {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Confirm Booking")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.blue)
                        }
                    }
                    .disabled(isLoading)
                }
            }
            .navigationTitle("Book a Table")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private func submitBooking() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await SupabaseManager.shared.createReservation(
                    ownerId: ownerId,
                    guests: guestCount,
                    date: selectedDate,
                    special: specialRequest
                )
                
                await MainActor.run {
                    isLoading = false
                    onSuccess()
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to book: \(error.localizedDescription)"
                }
            }
        }
    }
}

