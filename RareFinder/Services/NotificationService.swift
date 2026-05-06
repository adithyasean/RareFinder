import Foundation
import UserNotifications
import Observation

/// Thin wrapper around UserNotifications to schedule LOCAL alerts (per proposal).
@Observable
@MainActor
final class NotificationService {
    private(set) var authorized: Bool = false

    private let foregroundDelegate = ForegroundPresenter()

    init() {
        UNUserNotificationCenter.current().delegate = foregroundDelegate
        Task { await refreshAuthorization() }
    }

    func refreshAuthorization() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorized = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
            || settings.authorizationStatus == .ephemeral
    }

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

private final class ForegroundPresenter: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }
}
