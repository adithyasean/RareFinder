import SwiftUI
import MapKit
import CoreLocation

/// Lightweight modal for picking a coordinate by panning a draggable pin on
/// the map. Used by both the Intel and Bounty creation flows when the user
/// chooses "Pin from Map" instead of using their current GPS fix.
struct MapPinPicker: View {
    @Environment(\.dismiss) private var dismiss

    /// Bound to the parent so the chosen coordinate is reflected back.
    @Binding var coordinate: CLLocationCoordinate2D
    /// Optional radius preview (km). When non-nil a tinted MapCircle is drawn
    /// at the candidate centre so the user can see the search area as they
    /// adjust the pin — used by the Bounty flow.
    let radiusKm: Double?

    @State private var cameraPosition: MapCameraPosition

    init(coordinate: Binding<CLLocationCoordinate2D>, radiusKm: Double? = nil) {
        self._coordinate = coordinate
        self.radiusKm = radiusKm
        self._cameraPosition = State(initialValue: .camera(
            MapCamera(centerCoordinate: coordinate.wrappedValue, distance: 4000)
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MapReader { proxy in
                    Map(position: $cameraPosition) {
                        UserAnnotation()
                        Marker("Selected", systemImage: "mappin", coordinate: coordinate)
                            .tint(RFColor.primary)
                        if let radiusKm {
                            MapCircle(center: coordinate, radius: max(radiusKm, 0.1) * 1000)
                                .foregroundStyle(RFColor.tertiary.opacity(0.18))
                                .stroke(RFColor.tertiary.opacity(0.7), lineWidth: 2)
                        }
                    }
                    .mapStyle(.standard)
                    .mapControls {
                        MapUserLocationButton()
                        MapCompass()
                    }
                    .onTapGesture { screenPoint in
                        if let coord = proxy.convert(screenPoint, from: .local) {
                            coordinate = coord
                        }
                    }
                }

                // Crosshair overlay so users can also recenter the camera and
                // tap "Use Center" rather than tapping a precise spot.
                Image(systemName: "scope")
                    .font(.system(size: 36, weight: .black))
                    .foregroundStyle(RFColor.primary)
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                    .accessibilityHidden(true)
            }
            .navigationTitle("Drop Pin")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use This Spot") { dismiss() }
                        .fontWeight(.bold)
                }
            }
            .safeAreaInset(edge: .bottom) {
                coordReadout
                    .padding(RFSpacing.md)
                    .background(.ultraThinMaterial)
            }
        }
    }

    private var coordReadout: some View {
        HStack(spacing: RFSpacing.md) {
            Image(systemName: "mappin.circle.fill")
                .font(.title2)
                .foregroundStyle(RFColor.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text("PINNED")
                    .font(.system(size: 9, weight: .black))
                    .tracking(1.5)
                    .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.6))
                Text(String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude))
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundStyle(RFColor.onSurface)
            }
            Spacer()
        }
    }
}
