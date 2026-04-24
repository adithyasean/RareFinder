import SwiftUI
import CoreLocation

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @AppStorage("rf.useMetricDistance") private var useMetric = true
    @AppStorage("rf.ghostMode") private var ghostMode = false
    @AppStorage("rf.highFrequencyAlerts") private var highFrequency = true

    var body: some View {
        Form {
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
