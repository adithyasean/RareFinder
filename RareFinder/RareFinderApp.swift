//
//  RareFinderApp.swift
//  RareFinder
//
//  Created by Adithya Ekanayaka on 2026-04-24.
//

import SwiftUI
import SwiftData
import LocalAuthentication

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
    @State private var isUnlocked = false

    private var requiresBiometrics: Bool {
        appState.auth.biometricsEnabled && appState.auth.isSessionPersisted
    }

    var body: some View {
        Group {
            if !appState.hasCompletedOnboarding {
                OnboardingFlow()
            } else if requiresBiometrics && !isUnlocked {
                BiometricLockScreen(isUnlocked: $isUnlocked)
            } else {
                MainTabView()
            }
        }
        .rfAccessibilityOverrides()
        .task {
            if !requiresBiometrics {
                isUnlocked = true
            }
        }
        .onChange(of: isUnlocked) { _, unlocked in
            if unlocked && appState.hasCompletedOnboarding {
                Task {
                    await appState.sync.syncAll(context: context)
                    if let bounties = try? context.fetch(FetchDescriptor<Bounty>()) {
                        appState.location.monitorAll(bounties: bounties)
                    }
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                if !requiresBiometrics {
                    isUnlocked = true
                }
                if isUnlocked {
                    Task { await appState.sync.syncAll(context: context) }
                }
            case .background:
                if requiresBiometrics {
                    isUnlocked = false
                }
            default:
                break
            }
        }
    }
}

private struct BiometricLockScreen: View {
    @Environment(AppState.self) private var appState
    @Binding var isUnlocked: Bool
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: RFSpacing.lg) {
            Spacer()

            Image(systemName: appState.auth.biometricType == .faceID ? "faceid" : "touchid")
                .font(.system(size: 64))
                .foregroundStyle(RFColor.primary)

            Text("Rare Finder is Locked")
                .font(.rfTitle(28))

            Text("Authenticate to continue")
                .font(.rfBody())
                .foregroundStyle(.secondary)

            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(RFColor.tertiary)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, RFSpacing.lg)
            }

            Button {
                authenticate()
            } label: {
                Label(
                    appState.auth.biometricType == .faceID ? "Unlock with Face ID" : "Unlock with Touch ID",
                    systemImage: appState.auth.biometricType == .faceID ? "faceid" : "touchid"
                )
                .font(.rfBody())
                .frame(maxWidth: 260)
                .padding(.vertical, RFSpacing.sm)
            }
            .buttonStyle(.borderedProminent)
            .tint(RFColor.primary)

            Spacer()
            Spacer()
        }
        .padding()
        .task {
            authenticate()
        }
    }

    private func authenticate() {
        Task {
            do {
                try await appState.auth.authenticateWithBiometrics()
                errorMessage = nil
                isUnlocked = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
