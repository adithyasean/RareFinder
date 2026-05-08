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

    private let onboardingKey = "rf.onboardingComplete"

    init(
        location: LocationService? = nil,
        notifications: NotificationService? = nil,
        sync: SyncService? = nil
    ) {
        self.location = location ?? LocationService()
        self.notifications = notifications ?? NotificationService()
        self.sync = sync ?? SyncService()
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

    /// Seeds a full offline demo corpus when the SwiftData store is empty.
    /// Delegates to SeedData, which is idempotent and covers all model types.
    func bootstrap(context: ModelContext) {
        SeedData.bootstrapIfNeeded(context: context)
    }
}
