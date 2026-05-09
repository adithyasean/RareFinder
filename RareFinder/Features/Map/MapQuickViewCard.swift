import SwiftUI
import MapKit
import CoreLocation

/// Bottom-sheet "Quick View" card surfaced when a user taps a map item.
/// Shows minimal metadata plus two primary actions:
///   - "View More" → pushes the full DetailView
///   - "Navigate" → hands off to Apple Maps for turn-by-turn directions
///                  (hidden for Bounty items because they represent uncertain areas).
struct MapQuickViewCard: View {
    let bounty: Bounty
    let onViewMore: () -> Void
    let onDismiss: () -> Void

    private var canNavigate: Bool { !bounty.isBounty }

    var body: some View {
        VStack(alignment: .leading, spacing: RFSpacing.md) {
            grabber
            header
            summary
            metaRow
            actions
        }
        .padding(.horizontal, RFSpacing.lg)
        .padding(.top, RFSpacing.sm)
        .padding(.bottom, RFSpacing.lg)
    }

    private var grabber: some View {
        Capsule()
            .fill(RFColor.outlineVariant.opacity(0.5))
            .frame(width: 40, height: 4)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.bottom, 4)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: RFSpacing.md) {
            IconBadge(symbol: bounty.symbol, tint: bounty.status.tint, size: 52)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Tag(text: bounty.isBounty ? "BOUNTY" : "INTEL", tint: bounty.isBounty ? RFColor.tertiary : RFColor.secondary)
                    Tag(text: bounty.category.rawValue, tint: RFColor.outline.opacity(0.25), foreground: RFColor.onSurface)
                }
                Text(bounty.title)
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(RFColor.onSurface)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
    }

    private var summary: some View {
        Text(bounty.summary)
            .font(.rfBody(14))
            .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.85))
            .lineLimit(3)
    }

    private var metaRow: some View {
        HStack(spacing: 14) {
            Label(bounty.district, systemImage: "mappin.and.ellipse")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(RFColor.onSurfaceVariant)
            StatusPill(status: bounty.status, compact: true)
            if bounty.isBounty {
                Label(String(format: "%.1f km radius", bounty.radiusKm), systemImage: "scope")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(RFColor.tertiary)
            }
            Spacer(minLength: 0)
        }
    }

    private var actions: some View {
        HStack(spacing: RFSpacing.sm) {
            RFSecondaryButton(title: "View More", icon: "arrow.up.right.square.fill") {
                onViewMore()
            }
            if canNavigate {
                Button {
                    Self.openInMaps(coordinate: bounty.coordinate, name: bounty.title)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "location.north.line.fill")
                        Text("NAVIGATE")
                            .font(.system(size: 11, weight: .black))
                            .tracking(2.4)
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .foregroundStyle(.white)
                    .background(RFColor.primaryGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: RFColor.primary.opacity(0.3), radius: 10, y: 5)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Navigate to \(bounty.title)")
            }
        }
    }

    /// Hands off to the system Maps app for driving directions from the user's
    /// current location to the bounty coordinate. Uses MKMapItem so the user's
    /// preferred maps app (Apple Maps) handles routing natively.
    static func openInMaps(coordinate: CLLocationCoordinate2D, name: String) {
        let placemark = MKPlacemark(coordinate: coordinate)
        let item = MKMapItem(placemark: placemark)
        item.name = name
        item.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}
