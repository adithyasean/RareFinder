import SwiftUI
import SwiftData
import CoreLocation
import PhotosUI

/// "Create → Bounty" form. A Bounty represents a *search area* the hunter
/// wants help locating (no exact coordinate yet). The user picks an area
/// centre (current GPS or map pin), names what they're hunting for, and
/// drags a slider to choose the search **diameter** between 1 km and 60 km.
///
/// Bounties created here are **not** rendered as markers on the global map;
/// they only surface when picked from the Radar feed (see RadarView).
struct BountyFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query private var profiles: [HunterProfile]

    @State private var title: String = ""
    @State private var summary: String = ""
    @State private var detail: String = ""
    @State private var category: BountyCategory = .services
    @State private var status: BountyStatus = .unverified
    @State private var district: String = ""
    @State private var diameterKm: Double = 5

    enum LocationSource: String, CaseIterable, Identifiable {
        case currentGPS, pinned
        var id: String { rawValue }
        var label: String { self == .currentGPS ? "Current GPS" : "Pin From Map" }
    }
    @State private var locationSource: LocationSource = .currentGPS
    @State private var pinnedCoordinate: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 6.9271, longitude: 79.8612)
    @State private var showPinPicker = false

    @State private var submitting = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var successPoints = 0

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?

    private var radiusKm: Double { diameterKm / 2 }

    var body: some View {
        Form {
            Section {
                TextField("What are you searching for?", text: $title)
                TextField("Short summary", text: $summary, axis: .vertical)
                    .lineLimit(2...3)
                TextField("Details that might help others find it", text: $detail, axis: .vertical)
                    .lineLimit(3...6)
            } header: {
                Text("Bounty Brief")
            } footer: {
                Text("Anyone in the area can drop Intel inside your bounty radius to help you find it.")
                    .font(.caption)
            }

            Section {
                Picker("Category", selection: $category) {
                    ForEach(BountyCategory.allCases) { cat in
                        Label(cat.rawValue, systemImage: cat.symbol).tag(cat)
                    }
                }
                Picker("Initial Status", selection: $status) {
                    ForEach(BountyStatus.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                TextField("District / area name", text: $district)
            } header: {
                Text("Classification")
            }

            Section {
                Picker("Centre Source", selection: $locationSource) {
                    ForEach(LocationSource.allCases) { src in
                        Text(src.label).tag(src)
                    }
                }
                .pickerStyle(.segmented)

                if locationSource == .pinned {
                    Button {
                        if let here = appState.location.currentLocation?.coordinate {
                            pinnedCoordinate = here
                        }
                        showPinPicker = true
                    } label: {
                        Label(
                            String(format: "Pinned: %.4f, %.4f", pinnedCoordinate.latitude, pinnedCoordinate.longitude),
                            systemImage: "mappin.and.ellipse"
                        )
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Search Diameter", systemImage: "scope")
                            .font(.system(size: 14, weight: .heavy))
                        Spacer()
                        Text(String(format: "%.1f km", diameterKm))
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundStyle(RFColor.tertiary)
                    }
                    Slider(value: $diameterKm, in: 1...60, step: 0.5) {
                        Text("Diameter (km)")
                    } minimumValueLabel: {
                        Text("1")
                            .font(.caption2)
                    } maximumValueLabel: {
                        Text("60")
                            .font(.caption2)
                    }
                    .tint(RFColor.tertiary)

                    Text(String(format: "Radius ≈ %.2f km · area ≈ %.1f km²", radiusKm, .pi * radiusKm * radiusKm))
                        .font(.caption)
                        .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.6))
                }
                .padding(.vertical, 4)
            } header: {
                Text("Search Area")
            } footer: {
                Text("Bounties stay off the global map — they appear only when picked from the Bounty list.")
                    .font(.caption)
            }

            Section {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label(selectedImage == nil ? "Attach Reference Photo" : "Change Photo", systemImage: "camera.fill")
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
                        .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 280)
                        .background(RFColor.surfaceContainer)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } header: {
                Text("Reference (optional)")
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
                        Text("Post Bounty")
                            .fontWeight(.black)
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(title.isEmpty || summary.isEmpty || submitting)
            }
        }
        .sheet(isPresented: $showPinPicker) {
            MapPinPicker(coordinate: $pinnedCoordinate, radiusKm: radiusKm)
        }
        .fullScreenCoverCompat(isPresented: $showSuccess) {
            SuccessView(pointsAwarded: successPoints) {
                showSuccess = false
                dismiss()
            }
        }
    }

    @MainActor
    private func submit() async {
        submitting = true
        errorMessage = nil
        defer { submitting = false }

        let coord: CLLocationCoordinate2D
        switch locationSource {
        case .pinned: coord = pinnedCoordinate
        case .currentGPS:
            coord = appState.location.currentLocation?.coordinate
                ?? CLLocationCoordinate2D(latitude: 6.9271, longitude: 79.8612)
        }

        var remoteImageURL: String? = nil
        if let image = selectedImage, let data = image.jpegData(compressionQuality: 0.7) {
            remoteImageURL = try? await appState.sync.client.uploadImage(data: data)
        }

        let request = BackendClient.CreateBountyRequest(
            title: title,
            summary: summary.isEmpty ? title : summary,
            detail: detail.isEmpty ? summary : detail,
            category: category.rawValue,
            status: status.rawValue,
            latitude: coord.latitude,
            longitude: coord.longitude,
            district: district.isEmpty ? "Unzoned" : district,
            symbol: category.symbol,
            image_url: remoteImageURL,
            is_bounty: true,
            radius_km: radiusKm
        )

        do {
            _ = try await appState.sync.client.createBounty(request)
            await appState.sync.syncAll(context: context)

            successPoints = 0
            showSuccess = true
        } catch {
            errorMessage = "Bounty submission failed: \(error.localizedDescription)"
        }
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
