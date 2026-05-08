import SwiftUI
import SwiftData

struct IntelFeedView: View {
    @Query(sort: [SortDescriptor(\IntelReport.createdAt, order: .reverse)]) private var reports: [IntelReport]
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: RFSpacing.xl) {
                    ConnectionBanner(connection: appState.sync.connection) {
                        Task { await appState.sync.syncAll(context: context) }
                    }
                    .padding(.horizontal, 4)
                    if reports.isEmpty {
                        EmptyStateCard(
                            symbol: "antenna.radiowaves.left.and.right",
                            message: "Pull to sync the satellite feed."
                        )
                    } else {
                        ForEach(reports) { report in
                            NavigationLink {
                                if let bounty = report.bounty {
                                    DetailView(bounty: bounty)
                                } else {
                                    Text(report.note)
                                }
                            } label: {
                                IntelCard(report: report)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, RFSpacing.lg)
                .padding(.vertical, RFSpacing.md)
            }
            .refreshable {
                await appState.sync.syncAll(context: context)
            }
            .background(RFColor.surface)
            .navigationTitle("Satellite Feed")
        }
    }
}

private struct IntelCard: View {
    let report: IntelReport

    var body: some View {
        VStack(alignment: .leading, spacing: RFSpacing.md) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(
                        LinearGradient(colors: [
                            report.status.tint.opacity(0.85),
                            RFColor.onSurface
                        ], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .aspectRatio(16/10, contentMode: .fit)
                    .overlay(
                        Image(systemName: report.symbol)
                            .font(.system(size: 110, weight: .black))
                            .foregroundStyle(.white.opacity(0.2))
                            .offset(x: 60, y: 20)
                            .accessibilityHidden(true)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))

                HStack(spacing: 8) {
                    Tag(text: report.status.rawValue, tint: report.status.tint)
                    Tag(text: report.district, tint: .white.opacity(0.15), foreground: .white)
                }
                .padding(RFSpacing.md)
            }

            HStack(spacing: RFSpacing.sm) {
                AvatarView(seed: report.hunterSeed, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(report.hunterName.uppercased())
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(RFColor.onSurface)
                    Text(report.createdAt.rf_relative.uppercased())
                        .font(.system(size: 9, weight: .black))
                        .tracking(1.2)
                        .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.5))
                }
            }

            Text(report.note)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(RFColor.onSurface)
                .lineSpacing(2)

            HStack(spacing: 20) {
                Label {
                    Text("\(report.upvotes)")
                        .font(.system(size: 11, weight: .black))
                } icon: {
                    Image(systemName: "hand.thumbsup.fill")
                }
                .foregroundStyle(RFColor.secondary)
                Label {
                    Text("\(report.downvotes)")
                        .font(.system(size: 11, weight: .black))
                } icon: {
                    Image(systemName: "hand.thumbsdown.fill")
                }
                .foregroundStyle(RFColor.tertiary)
                Spacer()
                Label {
                    Text("+\(report.pointsAwarded) XP")
                        .font(.system(size: 10, weight: .black))
                        .tracking(1)
                } icon: {
                    Image(systemName: "bolt.fill")
                }
                .foregroundStyle(RFColor.primary)
            }
        }
    }
}

struct Tag: View {
    let text: String
    let tint: Color
    var foreground: Color = .white
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .black))
            .tracking(1.4)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundStyle(foreground)
            .background(Capsule().fill(tint))
    }
}

extension Date {
    var rf_relative: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: self, relativeTo: .now)
    }
}
