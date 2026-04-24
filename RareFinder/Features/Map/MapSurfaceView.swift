import SwiftUI
import SwiftData
import MapKit
import CoreLocation

/// Advanced iOS feature #1 — Dynamic Map Overlays.
/// Active bounties are rendered with a tinted MKCircle "Bounty Zone".
/// Stale areas (last update > 6h ago) are shaded with a "Fog of War" overlay.
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
                        // Bounty Zone — MKCircle rendered natively
                        MapCircle(center: bounty.coordinate, radius: 180)
                            .foregroundStyle(bounty.status.tint.opacity(isStale(bounty) ? 0.05 : 0.18))
                            .stroke(bounty.status.tint.opacity(isStale(bounty) ? 0.2 : 0.7), lineWidth: 2)

                        // Fog-of-War polygon for stale zones
                        if isStale(bounty) {
                            MapPolygon(coordinates: fogPolygon(around: bounty.coordinate))
                                .foregroundStyle(Color.black.opacity(0.20))
                        }

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

    /// Small rotated rectangle around a coordinate to draw a Fog-of-War overlay.
    private func fogPolygon(around center: CLLocationCoordinate2D) -> [CLLocationCoordinate2D] {
        let delta = 0.0035
        return [
            CLLocationCoordinate2D(latitude: center.latitude + delta,   longitude: center.longitude - delta*1.4),
            CLLocationCoordinate2D(latitude: center.latitude + delta*0.7, longitude: center.longitude + delta*1.4),
            CLLocationCoordinate2D(latitude: center.latitude - delta,   longitude: center.longitude + delta*1.2),
            CLLocationCoordinate2D(latitude: center.latitude - delta*0.7, longitude: center.longitude - delta*1.2)
        ]
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
                }
                Text(bounty.title)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(.white)
                Text(bounty.summary)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
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
