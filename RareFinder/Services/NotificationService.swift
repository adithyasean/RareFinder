import Foundation
import UserNotifications
import Observation

/// Thin wrapper around UserNotifications to schedule LOCAL alerts (per proposal).
@Observable
@MainActor
final class NotificationService {
    private(set) var authorized: Bool = false

    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            authorized = granted
        } catch {
            authorized = false
        }
    }

    /// Schedule a vicinity alert for a matched bounty.
    func scheduleVicinityAlert(title: String, body: String, after seconds: TimeInterval = 1) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
