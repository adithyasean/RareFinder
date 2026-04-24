import SwiftUI
import SwiftData
import CoreLocation

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @AppStorage("rf.useMetricDistance") private var useMetric = true
    @AppStorage("rf.ghostMode") private var ghostMode = false
    @AppStorage("rf.highFrequencyAlerts") private var highFrequency = true

    var body: some View {
        Form {
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
