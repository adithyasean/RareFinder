import SwiftUI
import SwiftData
import MapKit
import CoreLocation

/// Advanced iOS feature #1 — Dynamic Map Overlays.
///
/// The map shows two distinct layers:
///   • **Intel markers** — exact-location items (`isBounty == false`). Visible
///     at all times. Tapping a marker raises a Quick-View bottom sheet with
///     "View More" and "Navigate" actions instead of pushing a detail page.
///   • **Bounty zones** — radius-based search areas (`isBounty == true`). Hidden
///     from the global map; only rendered when the view is opened with a
///     `filterBountyID` (e.g. when the user picks a bounty from the feed),
///     in which case the Quick-View card pops up immediately.
struct MapSurfaceView: View {
    @Query private var bounties: [Bounty]
    @Environment(AppState.self) private var appState

    /// When non-nil, the map filters to ONLY this item (used when a bounty is
    /// selected from the list — see spec §2 Tab B and §1 Quick-View).
    let filterBountyID: UUID?

    /// `true` when this view is being pushed onto a parent NavigationStack
    /// (e.g. from RadarView's bounty list). In that case we render without
    /// our own NavigationStack so we don't end up with nested stacks.
    let embeddedInNavigationStack: Bool

    @State private var cameraPosition: MapCameraPosition = .camera(
        MapCamera(centerCoordinate: CLLocationCoordinate2D(latitude: 6.9271, longitude: 79.8612), distance: 6000)
    )
    @State private var selected: UUID?
    @State private var quickViewID: UUID?
    /// Drives the detail-view push for "View More" — works in both
    /// standalone and embedded modes by attaching to the nearest enclosing
    /// NavigationStack (ours or Radar's).
    @State private var detailRoute: DetailRoute?
    
    // Filter State
    @State private var selectedCategory: BountyCategory? = nil
    @State private var feedFilter: FeedFilter = .intel
    
    @Namespace private var mapScope

    private struct QuickViewToken: Identifiable, Equatable {
        let id: UUID
    }

    private struct DetailRoute: Identifiable, Hashable {
        let id: UUID
    }

    init(filterBountyID: UUID? = nil, embeddedInNavigationStack: Bool = false) {
        self.filterBountyID = filterBountyID
        self.embeddedInNavigationStack = embeddedInNavigationStack
    }

    var body: some View {
        if embeddedInNavigationStack {
            content
        } else {
            NavigationStack {
                content
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        ZStack(alignment: .top) {
            mapBody
            
            if filterBountyID == nil {
                filterOverlay
            }
            
            // Relocation Button positioned in the main view stack
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    MapUserLocationButton(scope: mapScope)
                        .padding(.trailing, RFSpacing.lg)
                        .padding(.bottom, 100) // Above tab bar
                }
            }
        }
        .toolbar(filterBountyID == nil ? .hidden : .visible, for: .navigationBar)
        .mapScope(mapScope)
            .navigationTitle(navTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .navigationDestination(item: $detailRoute) { route in
                if let bounty = bounties.first(where: { $0.id == route.id }) {
                    DetailView(bounty: bounty)
                }
            }
            .onChange(of: selected) { _, newValue in
                guard let id = newValue,
                      bounties.contains(where: { $0.id == id }) else { return }
                quickViewID = id
                // Reset selection so the marker can be tapped again later.
                selected = nil
            }
            .sheet(item: Binding(
                get: { quickViewID.map(QuickViewToken.init(id:)) },
                set: { quickViewID = $0?.id }
            )) { token in
                if let bounty = bounties.first(where: { $0.id == token.id }) {
                    quickViewSheet(for: bounty)
                }
            }
            .task {
                if appState.location.authorization == .notDetermined {
                    appState.location.requestAuthorization()
                }
                appState.location.start()
                appState.location.monitorAll(bounties: bounties)
                autoOpenFilteredBounty()
            }
            .onChange(of: filterBountyID) { _, _ in autoOpenFilteredBounty() }
    }

    private var navTitle: String {
        if let id = filterBountyID, let b = bounties.first(where: { $0.id == id }) {
            return b.title
        }
        return "Scanner"
    }

    @ViewBuilder
    private var mapBody: some View {
        Map(position: $cameraPosition, interactionModes: .all, selection: $selected, scope: mapScope) {
            UserAnnotation()

            ForEach(visibleItems) { bounty in
                if bounty.isBounty {
                    bountyZone(for: bounty)
                } else {
                    intelMarker(for: bounty)
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
        .ignoresSafeArea(edges: .bottom)
    }

    /// Global map shows items based on active filters. When `filterBountyID`
    /// is provided, the map is restricted to that single record (whether it's
    /// an Intel or a Bounty zone) so the user sees just the area they picked.
    private var visibleItems: [Bounty] {
        if let id = filterBountyID {
            return bounties.filter { $0.id == id }
        }
        return bounties.filter { b in
            let matchesType = (feedFilter == .intel) ? !b.isBounty : b.isBounty
            let matchesCat = selectedCategory == nil || b.category == selectedCategory
            return matchesType && matchesCat
        }
    }

    private var filterOverlay: some View {
        VStack(spacing: RFSpacing.md) {
            // Type Switcher
            Picker("Feed filter", selection: $feedFilter) {
                ForEach(FeedFilter.allCases) { f in
                    Label(f.label, systemImage: f.systemImage).tag(f)
                }
            }
            .pickerStyle(.segmented)
            .padding(RFSpacing.md)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)
            .padding(.horizontal, RFSpacing.lg)
            
            // Category Chips (Horizontal Scroll)
            if feedFilter == .intel {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        CategoryChip(title: "All Intelligence", isActive: selectedCategory == nil) {
                            selectedCategory = nil
                        }
                        ForEach(BountyCategory.allCases) { cat in
                            CategoryChip(title: cat.rawValue, isActive: selectedCategory == cat) {
                                selectedCategory = selectedCategory == cat ? nil : cat
                            }
                        }
                    }
                    .padding(.horizontal, RFSpacing.lg)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.top, filterBountyID == nil ? 12 : RFSpacing.sm)
        .animation(.spring(duration: 0.3), value: feedFilter)
    }

    @MapContentBuilder
    private func intelMarker(for bounty: Bounty) -> some MapContent {
        // Stale halo behind older intel — same fog-of-war effect as before.
        if isStale(bounty) {
            MapCircle(center: bounty.coordinate, radius: 520)
                .foregroundStyle(Color.black.opacity(0.10))
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        }

        MapCircle(center: bounty.coordinate, radius: 180)
            .foregroundStyle(bounty.status.tint.opacity(isStale(bounty) ? 0.05 : 0.18))
            .stroke(bounty.status.tint.opacity(isStale(bounty) ? 0.2 : 0.7), lineWidth: 2)

        Marker(bounty.title, systemImage: bounty.symbol, coordinate: bounty.coordinate)
            .tint(bounty.status.tint)
            .tag(bounty.id)
    }

    @MapContentBuilder
    private func bountyZone(for bounty: Bounty) -> some MapContent {
        // Bounty radius converted from kilometres to metres.
        let radiusMeters = max(bounty.radiusKm, 0.1) * 1000

        MapCircle(center: bounty.coordinate, radius: radiusMeters)
            .foregroundStyle(RFColor.tertiary.opacity(0.15))
            .stroke(RFColor.tertiary.opacity(0.7), lineWidth: 2)

        Marker(bounty.title, systemImage: "scope", coordinate: bounty.coordinate)
            .tint(RFColor.tertiary)
            .tag(bounty.id)
    }

    @ViewBuilder
    private func quickViewSheet(for bounty: Bounty) -> some View {
        MapQuickViewCard(
            bounty: bounty,
            onViewMore: {
                let id = bounty.id
                quickViewID = nil
                // Defer the push until after the sheet's dismissal animation
                // so the navigationDestination(item:) binding fires cleanly.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    detailRoute = DetailRoute(id: id)
                }
            },
            onDismiss: { quickViewID = nil }
        )
        .presentationDetents([.height(340), .medium])
        .presentationDragIndicator(.hidden)
        .presentationBackground(RFColor.surface)
    }

    /// When opened with a `filterBountyID`, immediately raise the quick-view
    /// card and recenter the camera on that target. Per spec §2 Tab B.
    private func autoOpenFilteredBounty() {
        guard let id = filterBountyID,
              let bounty = bounties.first(where: { $0.id == id }) else { return }
        let distance: CLLocationDistance = bounty.isBounty
            ? max(bounty.radiusKm * 3000, 4000)
            : 1500
        cameraPosition = .camera(
            MapCamera(centerCoordinate: bounty.coordinate, distance: distance)
        )
        // Defer slightly so the sheet animates in after the camera settles.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            quickViewID = bounty.id
        }
    }

    private func isStale(_ b: Bounty) -> Bool {
        Date.now.timeIntervalSince(b.updatedAt) > 6 * 3600
    }
}
