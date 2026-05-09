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
    @State private var appState: AppState

    init() {
        // UI-test launch flags. Must run before AppState reads UserDefaults.
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-RFUITestsReset") {
            UserDefaults.standard.removeObject(forKey: "rf.onboardingComplete")
            UserDefaults.standard.removeObject(forKey: "rf.authSession")
            UserDefaults.standard.removeObject(forKey: "rf.authToken")
        }
        if args.contains("-RFUITestsSkipOnboarding") {
            UserDefaults.standard.set(true, forKey: "rf.onboardingComplete")
        }
        _appState = State(initialValue: AppState())
    }

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
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingFlow()
            }
        }
        .rfAccessibilityOverrides()
        .task {
            await appState.sync.syncAll(context: context)
            if let bounties = try? context.fetch(FetchDescriptor<Bounty>()) {
                appState.location.monitorAll(bounties: bounties)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await appState.sync.syncAll(context: context) }
            }
        }
    }
}
