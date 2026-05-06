//
//  RareFinderApp.swift
//  RareFinder
//
//  Created by Adithya Ekanayaka on 2026-04-24.
//

import SwiftUI
import SwiftData

@main
struct RareFinderApp: App {
    @State private var appState = AppState()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Bounty.self,
            IntelReport.self,
            HunterProfile.self,
            Reward.self,
            AppNotification.self,
            ModerationFlag.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
        }
        .modelContainer(sharedModelContainer)
    }
}

private struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingFlow()
            }
        }
        .task {
            await appState.sync.syncAll(context: context)
            await appState.bootstrap(context: context)
            if let bounties = try? context.fetch(FetchDescriptor<Bounty>()) {
                appState.location.monitorAll(bounties: bounties)
            }
        }
    }
}
