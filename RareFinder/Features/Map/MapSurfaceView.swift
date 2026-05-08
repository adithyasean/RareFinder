import SwiftUI
import SwiftData
import MapKit
import CoreLocation

/// Advanced iOS feature #1 — Dynamic Map Overlays.
/// Active bounties are rendered with a tinted MapCircle "Bounty Zone".
/// Stale areas (last update > 6h ago) are shaded with a wider, dim "Fog of War" halo.
struct MapSurfaceView: View {
    @Query private var bounties: [Bounty]
    @Environment(AppState.self) private var appState

    @State private var cameraPosition: MapCameraPosition = .camera(
        MapCamera(centerCoordinate: CLLocationCoordinate2D(latitude: 6.9271, longitude: 79.8612), distance: 6000)
    )
    @State private var selected: Bounty?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $cameraPosition, interactionModes: .all, selection: $selected) {
                    UserAnnotation()

                    ForEach(bounties) { bounty in
                        // Fog-of-War halo behind stale zones — wider, dim circular haze.
                        if isStale(bounty) {
                            MapCircle(center: bounty.coordinate, radius: 520)
                                .foregroundStyle(Color.black.opacity(0.10))
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        }

                        // Bounty Zone — MapCircle rendered natively.
                        MapCircle(center: bounty.coordinate, radius: 180)
                            .foregroundStyle(bounty.status.tint.opacity(isStale(bounty) ? 0.05 : 0.18))
                            .stroke(bounty.status.tint.opacity(isStale(bounty) ? 0.2 : 0.7), lineWidth: 2)

                        Marker(bounty.title, systemImage: bounty.symbol, coordinate: bounty.coordinate)
                            .tint(bounty.status.tint)
                            .tag(bounty as Bounty?)
                    }
                }
                .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }
                .ignoresSafeArea(edges: .bottom)

                if let selected {
                    BountyPreviewCard(bounty: selected)
                        .padding(.horizontal, RFSpacing.md)
                        .padding(.bottom, RFSpacing.lg)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Scanner")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .task {
                if appState.location.authorization == .notDetermined {
                    appState.location.requestAuthorization()
                }
                appState.location.start()
                for b in bounties {
                    appState.location.monitor(bounty: b)
                }
            }
        }
    }

    private func isStale(_ b: Bounty) -> Bool {
        Date.now.timeIntervalSince(b.updatedAt) > 6 * 3600
    }
}

private struct BountyPreviewCard: View {
    let bounty: Bounty
    var body: some View {
        NavigationLink {
            DetailView(bounty: bounty)
        } label: {
            VStack(alignment: .leading, spacing: RFSpacing.sm) {
                HStack {
                    StatusPill(status: bounty.status, compact: true)
                    Spacer()
                    Text(bounty.district.uppercased())
                        .font(.system(size: 10, weight: .black))
                        .tracking(1.4)
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                HStack(alignment: .top, spacing: RFSpacing.md) {
                    VStack(alignment: .leading, spacing: RFSpacing.sm) {
                        Text(bounty.title)
                            .font(.system(size: 20, weight: .black))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                        Text(bounty.summary)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                    Spacer()
                    if let imageURL = bounty.imageURL, let url = URL(string: imageURL) {
                        AsyncImage(url: url) { image in
                            image.resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            RFColor.surfaceContainer
                        }
                        .frame(width: 80, height: 80)
                        .background(RFColor.surfaceContainer)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else {
                        HeroIconArt(symbol: bounty.symbol, palette: [bounty.status.tint], iconSize: 32)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                HStack {
                    Image(systemName: "scope")
                    Text("LAUNCH SCANNER")
                        .font(.system(size: 10, weight: .black))
                        .tracking(2)
                }
                .foregroundStyle(RFColor.primary)
                .padding(.top, 2)
            }
            .padding(RFSpacing.lg)
            .background(RFColor.onSurface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 18, y: 10)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(bounty.title), \(bounty.status.rawValue). Open scanner.")
    }
}
