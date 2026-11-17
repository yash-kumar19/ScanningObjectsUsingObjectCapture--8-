import SwiftUI
import UserNotifications
import AudioToolbox

class SettingsActionHandler: ObservableObject {
    var saveAction: (() async -> Bool)?
    var discardAction: (() -> Void)?
}

struct OwnerTabView: View {
    @State private var selectedTab = 0
    @State private var settingsHasChanges = false
    @State private var showUnsavedChangesAlert = false
    @State private var pendingTab = 0
    @StateObject private var settingsActionHandler = SettingsActionHandler()
    @ObservedObject private var orderManager = OwnerOrderManager.shared
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.background.ignoresSafeArea()
            
            // Content
            Group {
                switch selectedTab {
                case 0:
                    OwnerDashboardScreen(onTabSelect: { tabIndex in
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            selectedTab = tabIndex
                        }
                    })
                case 1:
                    OwnerMenuScreen()
                case 2:
                    OwnerGeneratorScreen()
                case 3:
                    OwnerOrdersScreen()
                case 4:
                    OwnerSettingsScreen(
                        onLogout: {
                            SupabaseManager.shared.logout()
                        },
                        hasUnsavedChangesBinding: $settingsHasChanges,
                        actionHandler: settingsActionHandler
                    )
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .id(selectedTab)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.25), value: selectedTab)
            
            // Custom Bottom Tab Bar for Owner
            OwnerBottomTabBar(
                selectedTab: $selectedTab,
                settingsHasChanges: $settingsHasChanges,
                showUnsavedChangesAlert: $showUnsavedChangesAlert,
                pendingTab: $pendingTab,
                badgeCount: orderManager.activeOrdersCount
            )
        }
        .ignoresSafeArea(.keyboard)
        .onAppear {
            orderManager.startPolling()
        }
        .onDisappear {
            orderManager.stopPolling()
        }
        .alert("Unsaved Changes", isPresented: $showUnsavedChangesAlert) {
            Button("Save Changes") {
                Task {
                    if let handler = settingsActionHandler.saveAction {
                        let success = await handler()
                        if success {
                            settingsHasChanges = false
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                selectedTab = pendingTab
                            }
                        }
                    }
                }
            }
            Button("Discard Changes", role: .destructive) {
                settingsActionHandler.discardAction?()
                settingsHasChanges = false
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    selectedTab = pendingTab
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You have unsaved changes in settings. Would you like to save them before leaving?")
        }
    }
}

struct OwnerBottomTabBar: View {
    @Binding var selectedTab: Int
    @Binding var settingsHasChanges: Bool
    @Binding var showUnsavedChangesAlert: Bool
    @Binding var pendingTab: Int
    let badgeCount: Int
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: 0) {
            OwnerTabBarItem(
                icon: "square.grid.2x2.fill",
                title: "Dashboard",
                index: 0,
                selectedTab: $selectedTab,
                settingsHasChanges: $settingsHasChanges,
                showUnsavedChangesAlert: $showUnsavedChangesAlert,
                pendingTab: $pendingTab,
                animation: animation
            )
            
            OwnerTabBarItem(
                icon: "list.bullet",
                title: "Menu",
                index: 1,
                selectedTab: $selectedTab,
                settingsHasChanges: $settingsHasChanges,
                showUnsavedChangesAlert: $showUnsavedChangesAlert,
                pendingTab: $pendingTab,
                animation: animation
            )
            
            OwnerTabBarItem(
                icon: "wand.and.stars",
                title: "Generator",
                index: 2,
                selectedTab: $selectedTab,
                settingsHasChanges: $settingsHasChanges,
                showUnsavedChangesAlert: $showUnsavedChangesAlert,
                pendingTab: $pendingTab,
                animation: animation
            )
            
            OwnerTabBarItem(
                icon: "tray.fill",
                title: "Orders",
                index: 3,
                selectedTab: $selectedTab,
                settingsHasChanges: $settingsHasChanges,
                showUnsavedChangesAlert: $showUnsavedChangesAlert,
                pendingTab: $pendingTab,
                badgeCount: badgeCount,
                animation: animation
            )
            
            OwnerTabBarItem(
                icon: "gearshape.fill",
                title: "Settings",
                index: 4,
                selectedTab: $selectedTab,
                settingsHasChanges: $settingsHasChanges,
                showUnsavedChangesAlert: $showUnsavedChangesAlert,
                pendingTab: $pendingTab,
                animation: animation
            )
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .fixedSize(horizontal: false, vertical: true)
        .background(
            Color(hex: "1e293b"),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.15),
                            .white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }
}

struct OwnerTabBarItem: View {
    let icon: String
    let title: String
    let index: Int
    @Binding var selectedTab: Int
    @Binding var settingsHasChanges: Bool
    @Binding var showUnsavedChangesAlert: Bool
    @Binding var pendingTab: Int
    var badgeCount: Int = 0
    let animation: Namespace.ID
    
    var body: some View {
        Button {
            if selectedTab == 4 && index != 4 && settingsHasChanges {
                pendingTab = index
                showUnsavedChangesAlert = true
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    selectedTab = index
                }
            }
        } label: {
            ZStack {
                // Active Background Pill
                if selectedTab == index {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "2b7fff").opacity(0.2),
                                    Color(hex: "3b82f6").opacity(0.2)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color(hex: "2b7fff").opacity(0.4), lineWidth: 1)
                        )
                        .shadow(color: Color(hex: "2b7fff").opacity(0.2), radius: 16, x: 0, y: 4)
                        .matchedGeometryEffect(id: "OWNER_TAB_BG", in: animation)
                }
                
                // Icon + Text
                VStack(spacing: 4) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: icon)
                            .font(.system(size: 20)) // Slightly smaller for 5 items
                            .foregroundColor(selectedTab == index ? Color(hex: "2b7fff") : Color.white.opacity(0.6))
                        
                        if badgeCount > 0 {
                            Text("\(badgeCount)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .frame(minWidth: 14, minHeight: 14)
                                .padding(.horizontal, 3)
                                .background(Color.orange)
                                .clipShape(Circle())
                                .offset(x: 10, y: -6)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .animation(.spring(response: 0.35, dampingFraction: 0.5, blendDuration: 0), value: badgeCount)
                    
                    Text(title)
                        .font(.system(size: 10, weight: .medium)) // Smaller text for 5 items
                        .foregroundColor(selectedTab == index ? Color(hex: "2b7fff") : Color.white.opacity(0.6))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .padding(.vertical, 8)
                .frame(maxWidth: 80) // Slightly narrower for 5 items
                .frame(minHeight: 52)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

@MainActor
class OwnerOrderManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = OwnerOrderManager()
    
    @Published var activeOrdersCount: Int = 0
    @Published var notificationPermissionStatus: UNAuthorizationStatus = .notDetermined
    @Published var showSyncWarning: Bool = false
    
    var isOrdersScreenVisible: Bool = false
    
    private var isPollingActive = false
    private var timer: Timer?
    private var fetchTask: Task<Void, Never>? = nil
    
    // Hash of the last set of orders to avoid redundant broadcasts
    private var lastOrdersHash: Int? = nil
    
    // Tracks notified order IDs to prevent duplicates
    private var notifiedOrderIDs = Set<String>()
    private var isFirstFetch = true
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        checkPermissionStatus()
    }
    
    func checkPermissionStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            guard let self = self else { return }
            Task { @MainActor in
                self.notificationPermissionStatus = settings.authorizationStatus
            }
        }
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            guard let self = self else { return }
            Task { @MainActor in
                self.checkPermissionStatus()
            }
            if granted {
                print("✅ Notification permissions granted")
            } else if let error = error {
                print("❌ Notification permissions error: \(error.localizedDescription)")
            }
        }
    }
    
    func startPolling(interval: TimeInterval = 5.0) {
        guard !isPollingActive else { return }
        isPollingActive = true
        
        pollOrders()
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.pollOrders()
            }
        }
    }
    
    func stopPolling() {
        timer?.invalidate()
        timer = nil
        isPollingActive = false
        fetchTask?.cancel()
    }
    
    private func pollOrders() {
        guard let restaurantId = SupabaseManager.shared.currentUser?.id else { return }
        
        fetchTask?.cancel()
        fetchTask = Task {
            do {
                let fetched = try await SupabaseManager.shared.fetchRestaurantOrders(restaurantId: restaurantId, limit: 50, offset: 0)
                if Task.isCancelled { return }
                
                await MainActor.run {
                    self.showSyncWarning = false
                    self.processFetchedOrders(fetched)
                }
            } catch {
                if Task.isCancelled { return }
                await MainActor.run {
                    self.showSyncWarning = true
                }
                print("❌ [OwnerOrderManager] Poll error: \(error)")
            }
        }
    }
    
    func didFetchOrders(_ fetched: [Order]) {
        self.processFetchedOrders(fetched)
    }
    
    private func processFetchedOrders(_ fetched: [Order]) {
        // 1. Calculate active orders count (placed, received, confirmed, accepted, preparing, ready)
        let active = fetched.filter {
            $0.status == .placed ||
            $0.status == .received ||
            $0.status == .confirmed ||
            $0.status == .accepted ||
            $0.status == .preparing ||
            $0.status == .ready
        }
        
        let newActiveCount = active.count
        if self.activeOrdersCount != newActiveCount {
            self.activeOrdersCount = newActiveCount
        }
        
        // 2. Identify new placed / received orders for alerts
        var newlyReceivedOrders: [Order] = []
        let now = Date()
        
        for order in fetched {
            let isInitialState = order.status == .placed || order.status == .received
            if isInitialState {
                if !notifiedOrderIDs.contains(order.id) {
                    var shouldNotify = !isFirstFetch
                    
                    // If it is the first fetch, check if the order was created in the last 2 minutes (120s)
                    if isFirstFetch, let createdAtDate = ISO8601DateFormatter.parse(order.created_at) {
                        let diff = now.timeIntervalSince(createdAtDate)
                        if diff < 120 {
                            shouldNotify = true
                        }
                    }
                    
                    if shouldNotify {
                        newlyReceivedOrders.append(order)
                    }
                    notifiedOrderIDs.insert(order.id)
                }
            }
        }
        
        if isFirstFetch {
            isFirstFetch = false
        }
        
        // Trigger alerts for newly received orders
        for order in newlyReceivedOrders {
            triggerNewOrderAlert(for: order)
        }
        
        // 3. Hash calculation and change-only broadcast
        let currentHash = calculateHash(for: fetched)
        if currentHash != lastOrdersHash {
            lastOrdersHash = currentHash
            NotificationCenter.default.post(
                name: .didReceiveOwnerOrders,
                object: nil,
                userInfo: ["orders": fetched]
            )
        }
    }
    
    private func calculateHash(for orders: [Order]) -> Int {
        var hash = orders.count
        for order in orders {
            hash = hash &* 31 &+ order.id.hashValue
            hash = hash &* 31 &+ order.status.rawValue.hashValue
        }
        return hash
    }
    
    private func triggerNewOrderAlert(for order: Order) {
        if isOrdersScreenVisible {
            // Owner is looking at the Orders Screen: trigger in-app feedback (haptics + sound)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            AudioServicesPlaySystemSound(1007) // Standard alert sound
        } else {
            // Owner is on another tab: trigger local push notification
            sendLocalPushNotification(for: order)
        }
    }
    
    private func sendLocalPushNotification(for order: Order) {
        let content = UNMutableNotificationContent()
        content.title = "New Order Received! 🍕"
        content.body = "Order \(order.displayOrderNumber) from \(order.customer_name ?? "Guest") total: \(String(format: "$%.2f", order.total))"
        content.sound = UNNotificationSound.default
        
        let request = UNNotificationRequest(
            identifier: "new_order_\(order.id)",
            content: content,
            trigger: nil // Deliver immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ [OwnerOrderManager] Error sending notification: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}

extension Notification.Name {
    static let didReceiveOwnerOrders = Notification.Name("didReceiveOwnerOrders")
}
