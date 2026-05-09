import Foundation
import Observation
import SwiftData

/// Central observable state shared through the environment.
@Observable
@MainActor
final class AppState {
    var hasCompletedOnboarding: Bool
    var isModeratorMode: Bool = false
    var selectedCategory: BountyCategory? = nil

    let location: LocationService
    let notifications: NotificationService
    let sync: SyncService
    let auth: AuthService
    let accessibility: AccessibilitySettings

    private let onboardingKey = "rf.onboardingComplete"

    init(
        location: LocationService? = nil,
        notifications: NotificationService? = nil,
        sync: SyncService? = nil,
        auth: AuthService? = nil,
        accessibility: AccessibilitySettings? = nil
    ) {
        let notifs = notifications ?? NotificationService()
        self.location = location ?? LocationService()
        self.notifications = notifs
        self.sync = sync ?? SyncService()
        self.auth = auth ?? AuthService(notifications: notifs)
        self.accessibility = accessibility ?? AccessibilitySettings()
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: onboardingKey)
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: onboardingKey)
    }

    func resetOnboarding() {
        hasCompletedOnboarding = false
        UserDefaults.standard.set(false, forKey: onboardingKey)
    }
}
