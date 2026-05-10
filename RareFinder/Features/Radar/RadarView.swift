import SwiftUI
import SwiftData

struct RadarView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query(sort: [SortDescriptor(\Bounty.intelScore, order: .reverse)]) private var bounties: [Bounty]
    @State private var searchText: String = ""
    @State private var selectedCategory: BountyCategory? = nil

    /// Top-level filter for the Radar feed. Intel = exact-location finds
    /// (services / goods), Bounties = open search areas. Search + category
    /// chips apply to whichever segment is active.
    @State private var feedFilter: FeedFilter = .intel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RFSpacing.lg) {
                    ConnectionBanner(connection: appState.sync.connection) {
                        Task { await appState.sync.syncAll(context: context) }
                    }
                    searchField
                    feedFilterPicker
                    if feedFilter == .intel {
                        categoryChips
                        nearbySection
                    } else {
                        bountyListSection
                    }
                }
                .padding(.horizontal, RFSpacing.lg)
                .padding(.vertical, RFSpacing.md)
            }
            .refreshable {
                await appState.sync.syncAll(context: context)
            }
            .background(RFColor.surface)
            .navigationTitle("Rare Finder")
            .navigationDestination(for: Bounty.self) { bounty in
                DetailView(bounty: bounty)
            }
            .navigationDestination(for: BountyCategory.self) { cat in
                CategoriesView(preselected: cat)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(destination: NotificationsView()) {
                        Image(systemName: "bell.fill")
                    }
                    .accessibilityLabel("Notifications")
                }
                ToolbarItem(placement: .secondaryAction) {
                    NavigationLink(destination: CategoriesView()) {
                        Label("Categories", systemImage: "square.grid.2x2.fill")
                    }
                    .accessibilityLabel("Categories")
                }
            }
        }
    }

    /// Segmented filter at the top of the feed. Switches the rest of the
    /// list between Intel (exact-location finds) and Bounty (radius-based
    /// search areas).
    private var feedFilterPicker: some View {
        Picker("Feed filter", selection: $feedFilter) {
            ForEach(FeedFilter.allCases) { f in
                Label(f.label, systemImage: f.systemImage).tag(f)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Feed filter — Intel or Bounty")
    }

    /// Bounty segment: lists radius-based search areas. Tapping a row pushes
    /// a filtered MapSurfaceView (just that area, with the Quick-View card
    /// auto-presented). Search text filters by title / district.
    @ViewBuilder
    private var bountyListSection: some View {
        let activeBounties = bounties.filter { b in
            guard b.isBounty else { return false }
            return searchText.isEmpty ||
                b.title.localizedCaseInsensitiveContains(searchText) ||
                b.district.localizedCaseInsensitiveContains(searchText)
        }
        VStack(alignment: .leading, spacing: RFSpacing.md) {
            Eyebrow(text: "Active Bounties")
                .padding(.leading, 4)
            if activeBounties.isEmpty {
                EmptyStateCard(symbol: "scope", message: "No active bounties match your search.")
            } else {
                ForEach(activeBounties) { bounty in
                    NavigationLink {
                        MapSurfaceView(filterBountyID: bounty.id, embeddedInNavigationStack: true)
                    } label: {
                        BountyAreaCard(bounty: bounty)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open \(bounty.title) bounty area on map")
                }
            }
        }
    }

    private var filteredBounties: [Bounty] {
        bounties.filter { b in
            // Exact-location Intel only — radius-based bounties live in
            // the Bounty segment (see bountyListSection).
            guard !b.isBounty else { return false }
            let matchesCat = selectedCategory == nil || b.category == selectedCategory
            let matchesText = searchText.isEmpty ||
                b.title.localizedCaseInsensitiveContains(searchText) ||
                b.district.localizedCaseInsensitiveContains(searchText)
            return matchesCat && matchesText
        }
    }

    private var searchField: some View {
        HStack(spacing: RFSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.5))
            TextField("Search for rare items or areas...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .medium))
        }
        .padding(RFSpacing.md)
        .rfCardStyle(cornerRadius: 18)
        .accessibilityLabel("Search bounties")
    }

    private var categoryChips: some View {
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
                NavigationLink(destination: CategoriesView()) {
                    ChipLabel(title: "More", isActive: false)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var nearbySection: some View {
        VStack(alignment: .leading, spacing: RFSpacing.md) {
            Eyebrow(text: "Nearby Insights")
                .padding(.leading, 4)
            if filteredBounties.isEmpty {
                EmptyStateCard(symbol: "scope", message: "No intel matches your filters.")
            } else {
                ForEach(filteredBounties) { bounty in
                    NavigationLink(value: bounty) {
                        BountyCard(bounty: bounty)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}


struct BountyCard: View {
    let bounty: Bounty
    var body: some View {
        HStack(spacing: RFSpacing.md) {
            IconBadge(symbol: bounty.symbol, tint: bounty.status.tint, size: 64)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(bounty.title)
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(RFColor.onSurface)
                        .lineLimit(1)
                    Spacer()
                    Text(bounty.district.uppercased())
                        .font(.system(size: 9, weight: .black))
                        .tracking(1.2)
                        .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.5))
                }
                Text(bounty.summary)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.7))
                    .lineLimit(2)
                StatusPill(status: bounty.status, compact: true)
            }
        }
        .padding(RFSpacing.md)
        .rfCardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(bounty.title), \(bounty.status.rawValue), \(bounty.district)")
    }
}

/// Compact list row for an "Active Bounty" area (radius-based search).
struct BountyAreaCard: View {
    let bounty: Bounty

    var body: some View {
        HStack(spacing: RFSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(RFColor.tertiary.opacity(0.12))
                    .frame(width: 64, height: 64)
                Image(systemName: "scope")
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(RFColor.tertiary)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(bounty.title)
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(RFColor.onSurface)
                        .lineLimit(1)
                    Spacer()
                    Text(String(format: "%.1f km", bounty.radiusKm * 2))
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(RFColor.tertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(RFColor.tertiary.opacity(0.12)))
                }
                Text(bounty.summary)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.7))
                    .lineLimit(2)
                Label(bounty.district.uppercased(), systemImage: "mappin.and.ellipse")
                    .font(.system(size: 9, weight: .black))
                    .tracking(1.2)
                    .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.55))
            }
        }
        .padding(RFSpacing.md)
        .rfCardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Bounty \(bounty.title), \(bounty.radiusKm * 2) kilometre search area in \(bounty.district)")
    }
}

struct EmptyStateCard: View {
    let symbol: String
    let message: String
    var body: some View {
        VStack(spacing: RFSpacing.sm) {
            Image(systemName: symbol)
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.4))
            Text(message)
                .font(.rfBody())
                .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 140)
        .padding(RFSpacing.lg)
        .rfCardStyle()
    }
}
