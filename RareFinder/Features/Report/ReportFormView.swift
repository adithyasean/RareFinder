import SwiftUI
import SwiftData
import CoreLocation

struct ReportFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query private var bounties: [Bounty]
    @Query private var profiles: [HunterProfile]

    let prefilledBounty: Bounty?

    @State private var category: BountyCategory = .fuelGrid
    @State private var status: BountyStatus = .available
    @State private var note: String = ""
    @State private var locationSet = false
    @State private var photoAttached = false
    @State private var matchedBounty: Bounty?
    @State private var showSuccess = false
    @State private var awardedPoints = 0
    @State private var submitting = false
    @State private var errorMessage: String?

    init(prefilledBounty: Bounty? = nil) {
        self.prefilledBounty = prefilledBounty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Asset Category", selection: $category) {
                        ForEach(BountyCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.symbol).tag(cat)
                        }
                    }
                    Picker("Status", selection: $status) {
                        ForEach(BountyStatus.allCases) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    if !bounties.isEmpty {
                        Picker("Link to Bounty (optional)", selection: $matchedBounty) {
                            Text("New Bounty").tag(Bounty?.none)
                            ForEach(bounties) { b in
                                Text(b.title).tag(Bounty?.some(b))
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }
                } header: {
                    Text("Intel Classification")
                }

                Section {
                    TextField("Describe what you observed…", text: $note, axis: .vertical)
                        .lineLimit(4...8)
                } header: {
                    Text("Observation")
                }

                Section {
                    Toggle(isOn: $locationSet) {
                        Label("Pin Location (geofence anchor)", systemImage: "location.viewfinder")
                    }
                    Toggle(isOn: $photoAttached) {
                        Label("Attach Proof Photo", systemImage: "camera.fill")
                    }
                } header: {
                    Text("Verification")
                } footer: {
                    Text("Geofenced proof-of-presence awards bonus Trust Points when you are within 50 m of the bounty.")
                        .font(.caption)
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(RFColor.tertiary)
                    }
                }

                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            if submitting { ProgressView() }
                            Text("Transmit Intelligence")
                                .fontWeight(.black)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(note.isEmpty || submitting)
                    .accessibilityHint(note.isEmpty ? "Add an observation note to enable submission" : "")
                }
            }
            .navigationTitle("Submit Intel")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if let b = prefilledBounty, matchedBounty == nil {
                    matchedBounty = b
                    category = b.category
                    status = b.status
                }
            }
            .fullScreenCoverCompat(isPresented: $showSuccess) {
                SuccessView(pointsAwarded: awardedPoints) {
                    showSuccess = false
                    dismiss()
                }
            }
        }
    }

    @MainActor
    private func submit() async {
        submitting = true
        errorMessage = nil
        defer { submitting = false }

        let profile = profiles.first
        let verified = verifyGeofence() || locationSet

        let coord = matchedBounty?.coordinate
            ?? appState.location.currentLocation?.coordinate
            ?? CLLocationCoordinate2D(latitude: 6.9271, longitude: 79.8612)

        let request = BackendClient.SubmitReportRequest(
            bounty_id: matchedBounty?.id,
            hunter_name: profile?.displayName ?? "Guest Hunter",
            hunter_seed: profile?.avatarSeed,
            note: note,
            status: status.rawValue,
            district: matchedBounty?.district ?? "Live",
            latitude: coord.latitude,
            longitude: coord.longitude,
            symbol: category.symbol,
            is_geofence_verified: verified
        )

        do {
            let response = try await appState.sync.client.submitReport(request)
            awardedPoints = response.points_awarded
            // Re-pull the corpus so SwiftData reflects the authoritative
            // backend state (new bounty, new report, updated counters,
            // updated hunter balance).
            await appState.sync.syncAll(context: context)
            await appState.notifications.scheduleVicinityAlert(
                title: "Intel logged",
                body: "You earned +\(response.points_awarded) Trust XP. Thanks, hunter.",
                after: 0.5
            )
            showSuccess = true
        } catch {
            errorMessage = "Submission failed: \(error.localizedDescription)"
        }
    }

    private func verifyGeofence() -> Bool {
        guard let here = appState.location.currentLocation,
              let target = matchedBounty?.coordinate else { return false }
        return LocationService.isWithinGeofence(
            userCoordinate: here.coordinate,
            targetCoordinate: target
        )
    }
}

private extension View {
    @ViewBuilder
    func fullScreenCoverCompat<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        #if os(iOS)
        self.fullScreenCover(isPresented: isPresented, content: content)
        #else
        self.sheet(isPresented: isPresented, content: content)
        #endif
    }
}
