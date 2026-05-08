import SwiftUI
import SwiftData
import CoreLocation
import PhotosUI

struct ReportFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query private var bounties: [Bounty]
    @Query private var profiles: [HunterProfile]

    let prefilledBounty: Bounty?

    @State private var category: BountyCategory = .fuelGrid
    @State private var status: BountyStatus = .available
    @State private var bountyTitle: String = ""
    @State private var note: String = ""
    @State private var locationSet = false
    @State private var matchedBounty: Bounty?
    @State private var showSuccess = false
    @State private var awardedPoints = 0
    @State private var submitting = false
    @State private var errorMessage: String?
    
    // Image selection state
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?

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
                    if matchedBounty == nil {
                        TextField("Bounty Name", text: $bountyTitle)
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
                    
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Label(selectedImage == nil ? "Attach Proof Photo" : "Change Photo", systemImage: "camera.fill")
                    }
                    .onChange(of: selectedItem) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                selectedImage = image
                            }
                        }
                    }
                    
                    if let selectedImage {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 150, maxHeight: 280)
                            .background(RFColor.surfaceContainer)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(alignment: .topTrailing) {
                                Button {
                                    self.selectedImage = nil
                                    self.selectedItem = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.white, .black.opacity(0.6))
                                        .padding(8)
                                }
                            }
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

        // Upload actual image to MinIO if one was attached
        var remoteImageURL: String? = nil
        if let image = selectedImage, let data = image.jpegData(compressionQuality: 0.7) {
            do {
                remoteImageURL = try await appState.sync.client.uploadImage(data: data)
            } catch {
                print("Image upload failed: \(error)")
                // Continue with submission anyway, or handle error?
                // For now, we'll continue but without the image if upload fails.
            }
        }

        let request = BackendClient.SubmitReportRequest(
            bounty_id: matchedBounty?.id,
            bounty_title: matchedBounty == nil ? bountyTitle.isEmpty ? nil : bountyTitle : nil,
            hunter_name: profile?.displayName ?? "Guest Hunter",
            hunter_seed: profile?.avatarSeed,
            note: note,
            status: status.rawValue,
            district: matchedBounty?.district ?? "Live",
            latitude: coord.latitude,
            longitude: coord.longitude,
            symbol: category.symbol,
            is_geofence_verified: verified,
            image_url: remoteImageURL
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
