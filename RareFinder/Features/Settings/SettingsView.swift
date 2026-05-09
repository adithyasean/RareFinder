import SwiftUI
import SwiftData
import CoreLocation

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Query private var profiles: [HunterProfile]
    @AppStorage("rf.useMetricDistance") private var useMetric = true
    @AppStorage("rf.ghostMode") private var ghostMode = false
    @AppStorage("rf.highFrequencyAlerts") private var highFrequency = true
    @State private var showAuthSheet = false
    @State private var authMode: AuthService.Mode = .login

    private var profile: HunterProfile? { profiles.first }

    var body: some View {
        @Bindable var a11y = appState.accessibility
        return Form {
            accountSection
            accessibilitySection(a11y: a11y)

            Section("Backend Sync") {
                HStack {
                    Label("Status", systemImage: "arrow.triangle.2.circlepath")
                    Spacer()
                    Text(syncSummary).foregroundStyle(.secondary)
                }
                Button {
                    Task { await appState.sync.syncAll(context: context) }
                } label: {
                    Label("Sync Now", systemImage: "arrow.down.circle.fill")
                }
                Button(role: .destructive) {
                    resetLocalCache()
                } label: {
                    Label("Reset Local Cache", systemImage: "trash")
                }
            }

            Section("Grid Preferences") {
                Toggle("Metric distance", isOn: $useMetric)
                Toggle("Ghost Mode (hide from map)", isOn: $ghostMode)
                Toggle("High-frequency vicinity alerts", isOn: $highFrequency)
            }

            Section("Permissions") {
                HStack {
                    Label("Location", systemImage: "location.fill")
                    Spacer()
                    Text(statusDescription(appState.location.authorization))
                        .foregroundStyle(.secondary)
                }
                Button {
                    appState.location.requestAuthorization()
                } label: {
                    Label("Request Location", systemImage: "location.viewfinder")
                }

                Button {
                    Task { await appState.notifications.requestAuthorization() }
                } label: {
                    Label("Request Notifications", systemImage: "bell.badge.fill")
                }
            }

            Section {
                Toggle(isOn: Binding(
                    get: { profile?.isModerator ?? false },
                    set: { newValue in
                        profile?.isModerator = newValue
                        try? context.save()
                    }
                )) {
                    Label("Moderator mode", systemImage: "checkmark.shield.fill")
                }
            } header: {
                Text("Developer")
            } footer: {
                Text("Unlocks the Moderator dashboard from the Hunter Profile toolbar.")
                    .font(.caption)
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0").foregroundStyle(.secondary)
                }
                HStack {
                    Text("Build")
                    Spacer()
                    Text("\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")").foregroundStyle(.secondary)
                }
            }

            Section {
                Button(role: .destructive) {
                    appState.resetOnboarding()
                } label: {
                    Label("Reset Onboarding", systemImage: "arrow.counterclockwise")
                }
            }
        }
        .navigationTitle("Settings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showAuthSheet) {
            NavigationStack {
                AuthView(mode: authMode) {
                    showAuthSheet = false
                    Task { await appState.sync.syncAll(context: context) }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { showAuthSheet = false }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var accountSection: some View {
        Section("Account") {
            if let session = appState.auth.session {
                HStack {
                    Label("Signed in as", systemImage: "person.crop.circle.fill")
                    Spacer()
                    Text(session.displayName).foregroundStyle(.secondary)
                }
                if let email = session.email {
                    HStack {
                        Label("Email", systemImage: "envelope.fill")
                        Spacer()
                        Text(email).foregroundStyle(.secondary).font(.caption)
                    }
                }
                Button(role: .destructive) {
                    Task {
                        await appState.auth.logout()
                        await appState.sync.syncAll(context: context)
                    }
                } label: {
                    Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
                .accessibilityIdentifier("settings_logout")
            } else {
                HStack {
                    Label("Status", systemImage: "person.crop.circle.badge.questionmark")
                    Spacer()
                    Text("Guest").foregroundStyle(.secondary)
                }
                Button {
                    authMode = .login
                    showAuthSheet = true
                } label: {
                    Label("Log In", systemImage: "key.fill")
                }
                .accessibilityIdentifier("settings_login")
                Button {
                    authMode = .signup
                    showAuthSheet = true
                } label: {
                    Label("Sign Up", systemImage: "person.crop.circle.badge.plus")
                }
                .accessibilityIdentifier("settings_signup")
            }
        }
    }

    @ViewBuilder
    private func accessibilitySection(a11y: AccessibilitySettings) -> some View {
        Section {
            Toggle(isOn: Binding(
                get: { a11y.boldText },
                set: { a11y.boldText = $0 }
            )) {
                Label("Bold Text", systemImage: "bold")
            }
            .accessibilityIdentifier("a11y_bold")

            Toggle(isOn: Binding(
                get: { a11y.highContrast },
                set: { a11y.highContrast = $0 }
            )) {
                Label("Increase Contrast", systemImage: "circle.lefthalf.filled")
            }
            .accessibilityIdentifier("a11y_contrast")

            Toggle(isOn: Binding(
                get: { a11y.reduceMotion },
                set: { a11y.reduceMotion = $0 }
            )) {
                Label("Reduce Motion", systemImage: "tortoise.fill")
            }
            .accessibilityIdentifier("a11y_motion")

            Toggle(isOn: Binding(
                get: { a11y.voiceHints },
                set: { a11y.voiceHints = $0 }
            )) {
                Label("Voice Hints", systemImage: "speaker.wave.2.fill")
            }
            .accessibilityIdentifier("a11y_voice")

            Toggle(isOn: Binding(
                get: { a11y.hapticFeedback },
                set: { a11y.hapticFeedback = $0 }
            )) {
                Label("Haptic Feedback", systemImage: "waveform.path")
            }
            .accessibilityIdentifier("a11y_haptics")

            Picker(selection: Binding(
                get: { a11y.textScale },
                set: { a11y.textScale = $0 }
            )) {
                ForEach(AccessibilitySettings.TextScale.allCases) { scale in
                    Text(scale.label).tag(scale)
                }
            } label: {
                Label("Text Size", systemImage: "textformat.size")
            }
            .accessibilityIdentifier("a11y_text_size")

            HStack(spacing: RFSpacing.sm) {
                Button {
                    a11y.enableAll()
                } label: {
                    Label("Enable All", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("a11y_enable_all")

                Button(role: .destructive) {
                    a11y.resetAll()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("a11y_reset")
            }
        } header: {
            Text("Accessibility")
        } footer: {
            Text("Quick triggers layered on top of the system Accessibility settings — useful for verifying accessible layouts during testing.")
                .font(.caption)
        }
    }

    private var syncSummary: String {
        switch appState.sync.status {
        case .idle: return "Idle"
        case .syncing: return "Syncing…"
        case .synced(let date):
            let f = RelativeDateTimeFormatter()
            f.unitsStyle = .short
            return "Synced " + f.localizedString(for: date, relativeTo: .now)
        case .offline(let msg): return "Offline — \(msg.prefix(30))"
        }
    }

    private func resetLocalCache() {
        for type in [
            Bounty.self as any PersistentModel.Type,
            IntelReport.self,
            Reward.self,
            AppNotification.self,
            ModerationFlag.self,
            HunterProfile.self
        ] {
            try? context.delete(model: type)
        }
        try? context.save()
        Task { await appState.sync.syncAll(context: context) }
    }

    private func statusDescription(_ s: CLAuthorizationStatus) -> String {
        switch s {
        case .authorizedAlways: return "Always"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not set"
        #if !os(macOS)
        case .authorizedWhenInUse: return "When in use"
        #endif
        @unknown default: return "Unknown"
        }
    }
}
