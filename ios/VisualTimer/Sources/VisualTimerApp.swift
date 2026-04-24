import SwiftUI
import UserNotifications

@main
struct VisualTimerApp: App {
    var body: some Scene {
        WindowGroup {
            TimerView()
                .onAppear {
                    // P1-04: request notification authorization so timer-end alerts work in background
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
                }
        }
    }
}
