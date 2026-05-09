import SwiftUI
import SwiftData

struct CategoriesView: View {
    var preselected: BountyCategory? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Query private var bounties: [Bounty]

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: RFSpacing.md)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RFSpacing.lg) {
                SectionHeader(title: "Intelligence Filters", eyebrow: "Explore Market")
                Text("Discover localized reports on the world's most elusive assets. Focus your scanner.")
                    .font(.rfBody())
                    .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.7))

                LazyVGrid(columns: columns, spacing: RFSpacing.md) {
                    ForEach(BountyCategory.allCases) { cat in
                        NavigationLink {
                            RadarFilteredView(category: cat)
                        } label: {
                            CategoryTile(category: cat, activeCount: count(for: cat))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(RFSpacing.lg)
        }
        .background(RFColor.surface)
        .navigationTitle("Categories")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func count(for cat: BountyCategory) -> Int {
        bounties.filter { $0.category == cat }.count
    }
}

private struct CategoryTile: View {
    let category: BountyCategory
    let activeCount: Int
    var body: some View {
        VStack(alignment: .leading, spacing: RFSpacing.md) {
            IconBadge(symbol: category.symbol, tint: RFColor.primary, size: 48)
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 4) {
                Text(category.rawValue)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(RFColor.onSurface)
                Text("\(activeCount) LIVE NODES")
                    .font(.system(size: 9, weight: .black))
                    .tracking(1.4)
                    .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
        .padding(RFSpacing.md)
        .rfCardStyle(cornerRadius: 28)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(category.rawValue), \(activeCount) live nodes")
    }
}

struct RadarFilteredView: View {
    let category: BountyCategory
    @Query private var all: [Bounty]
    var filtered: [Bounty] { all.filter { $0.category == category } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RFSpacing.md) {
                SectionHeader(title: category.rawValue, eyebrow: "Filtered Grid")
                if filtered.isEmpty {
                    EmptyStateCard(symbol: category.symbol, message: "No live nodes in this category yet.")
                } else {
                    ForEach(filtered) { bounty in
                        NavigationLink {
                            DetailView(bounty: bounty)
                        } label: {
                            BountyCard(bounty: bounty)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(RFSpacing.lg)
        }
        .background(RFColor.surface)
        .navigationTitle(category.rawValue)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
