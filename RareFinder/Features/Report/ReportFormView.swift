import SwiftUI
import SwiftData
import CoreLocation

struct ReportFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query private var bounties: [Bounty]
    @Query private var profiles: [HunterProfile]

    @State private var category: BountyCategory = .fuelGrid
    @State private var status: BountyStatus = .available
    @State private var note: String = ""
    @State private var locationSet = false
    @State private var photoAttached = false
    @State private var matchedBounty: Bounty?
    @State private var showSuccess = false
    @State private var awardedPoints = 0
    @State private var submitting = false

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

                Section {
                    Button {
                        submit()
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
            .fullScreenCoverCompat(isPresented: $showSuccess) {
                SuccessView(pointsAwarded: awardedPoints) {
                    showSuccess = false
                    dismiss()
                }
            }
        }
    }

    private func submit() {
        submitting = true
        let profile = profiles.first
        let verified = verifyGeofence()
        let quality: EconomyService.ReportQuality = matchedBounty == nil ? .firstSighting : .verification
        let points = EconomyService.pointsForReport(quality: quality, isGeofenceVerified: verified || locationSet)
        awardedPoints = points

        let coord = matchedBounty?.coordinate ?? appState.location.currentLocation?.coordinate
            ?? CLLocationCoordinate2D(latitude: 6.9271, longitude: 79.8612)

        let report = IntelReport(
            hunterName: profile?.displayName ?? "You",
            hunterSeed: profile?.avatarSeed,
            note: note,
            status: status,
            district: matchedBounty?.district ?? "You",
            coordinate: coord,
            symbol: category.symbol,
            pointsAwarded: points,
            bounty: matchedBounty
        )
        context.insert(report)

        if let b = matchedBounty {
            b.verifiedCount += 1
            b.upvotes += 1
            b.updatedAt = .now
            b.status = status
        } else {
            let newBounty = Bounty(
                title: "New Intel — \(category.rawValue)",
                summary: String(note.prefix(60)),
                detail: note,
                category: category,
                status: status,
                coordinate: coord,
                district: "Live",
                verifiedCount: 1,
                upvotes: 1
            )
            context.insert(newBounty)
            report.bounty = newBounty
        }

        profile?.points += points
        profile?.verifications += 1

        try? context.save()

        Task {
            await appState.notifications.scheduleVicinityAlert(
                title: "Intel logged",
                body: "You earned +\(points) Trust XP. Thanks, hunter.",
                after: 0.5
            )
        }

        submitting = false
        showSuccess = true
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
