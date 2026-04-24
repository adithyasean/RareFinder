import SwiftUI
import SwiftData

struct RadarView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query(sort: [SortDescriptor(\Bounty.intelScore, order: .reverse)]) private var bounties: [Bounty]
    @State private var searchText: String = ""
    @State private var selectedCategory: BountyCategory? = nil
    @State private var viewMode: ViewMode = .list

    enum ViewMode: String, CaseIterable { case list = "List View", map = "Map" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RFSpacing.lg) {
                    searchField
                    categoryChips
                    viewToggle
                    nearbySection
                }
                .padding(.horizontal, RFSpacing.lg)
                .padding(.vertical, RFSpacing.md)
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
            }
        }
    }

    private var filteredBounties: [Bounty] {
        bounties.filter { b in
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
            }
        }
    }

    private var viewToggle: some View {
        HStack(spacing: 4) {
            ForEach(ViewMode.allCases, id: \.rawValue) { mode in
                Button {
                    viewMode = mode
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 13, weight: .heavy))
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .foregroundStyle(viewMode == mode ? RFColor.onSurface : RFColor.onSurfaceVariant.opacity(0.6))
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(viewMode == mode ? Color.white : .clear)
                                .shadow(color: .black.opacity(viewMode == mode ? 0.06 : 0), radius: 3, y: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(RFColor.surfaceContainer, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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

struct CategoryChip: View {
    let title: String
    let isActive: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .heavy))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .foregroundStyle(isActive ? .white : RFColor.onSurfaceVariant)
                .background(
                    Capsule().fill(isActive ? AnyShapeStyle(RFColor.primaryGradient) : AnyShapeStyle(Color.white))
                )
                .overlay(Capsule().stroke(isActive ? RFColor.primary : RFColor.outlineVariant.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? .isSelected : [])
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
