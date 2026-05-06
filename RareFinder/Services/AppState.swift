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

    /// Inserts demo moderation flags locally so the Moderator screen has content
    /// even when the backend is unreachable. Idempotent — only runs when the
    /// SwiftData store has zero flags after the most recent sync attempt.
    func bootstrap(context: ModelContext) {
        let descriptor = FetchDescriptor<ModerationFlag>()
        let existing = (try? context.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return }
        let demo: [ModerationFlag] = [
            ModerationFlag(
                title: "Phantom Fuel Drop — Sector 4",
                handle: "@grid_walker",
                reason: "Reported full stock at a station that closed last week. Three users contested.",
                sightingCount: 3
            ),
            ModerationFlag(
                title: "Spoofed Pharmacy Sighting",
                handle: "@delta_runner",
                reason: "Coordinates resolved 1.2 km from the reporter's last known location.",
                sightingCount: 2
            ),
            ModerationFlag(
                title: "Duplicate Collector Drop",
                handle: "@nova_one",
                reason: "Identical photo submitted from two accounts within four minutes.",
                sightingCount: 4
            )
        ]
        for flag in demo { context.insert(flag) }
        try? context.save()
    }
}
