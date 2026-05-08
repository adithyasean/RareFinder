import SwiftUI
import SwiftData

struct NotificationsView: View {
    @Query(sort: [SortDescriptor(\AppNotification.createdAt, order: .reverse)]) private var notifications: [AppNotification]
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RFSpacing.lg) {
                ConnectionBanner(connection: appState.sync.connection) {
                    Task { await appState.sync.syncAll(context: context) }
                }
                if !today.isEmpty {
                    section(title: "Grid Cycle: Today", items: today)
                }
                if !earlier.isEmpty {
                    section(title: "Previous Cycle", items: earlier)
                }
                if notifications.isEmpty {
                    EmptyStateCard(symbol: "bell.slash.fill", message: "No alerts yet. Pull to sync, or enable location to activate the grid.")
                }
            }
            .padding(RFSpacing.lg)
        }
        .refreshable {
            await appState.sync.syncAll(context: context)
        }
        .background(RFColor.surface)
        .navigationTitle("Notifications")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if !notifications.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button("Mark all read") {
                        for n in notifications { n.read = true }
                        try? context.save()
                    }
                }
            }
        }
    }

    private var today: [AppNotification] {
        notifications.filter { Calendar.current.isDateInToday($0.createdAt) }
    }
    private var earlier: [AppNotification] {
        notifications.filter { !Calendar.current.isDateInToday($0.createdAt) }
    }

    private func section(title: String, items: [AppNotification]) -> some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Eyebrow(text: title).padding(.leading, 4)
            ForEach(items) { n in
                NotificationRow(n: n)
            }
        }
    }
}

private struct NotificationRow: View {
    let n: AppNotification
    var body: some View {
        HStack(alignment: .top, spacing: RFSpacing.md) {
            IconBadge(symbol: n.symbol, tint: tint, size: 48)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(n.title)
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(RFColor.onSurface)
                    Spacer()
                    Text(n.createdAt.rf_relative.uppercased())
                        .font(.system(size: 9, weight: .black))
                        .tracking(1.3)
                        .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.5))
                }
                Text(n.body)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.7))
            }
            if !n.read {
                Circle().fill(RFColor.primary).frame(width: 8, height: 8)
                    .padding(.top, 6)
            }
        }
        .padding(RFSpacing.md)
        .rfCardStyle(cornerRadius: 28)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(n.title). \(n.body). \(n.read ? "Read" : "Unread")")
    }

    var tint: Color {
        switch n.kind {
        case .vicinity: return RFColor.primary
        case .verification: return RFColor.secondary
        case .reward: return RFColor.primaryDeep
        case .system: return RFColor.outline
        }
    }
}
