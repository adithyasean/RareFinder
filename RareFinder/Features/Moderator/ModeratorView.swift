import SwiftUI
import SwiftData

struct ModeratorView: View {
    @Query(sort: [SortDescriptor(\ModerationFlag.createdAt, order: .reverse)]) private var flags: [ModerationFlag]
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @State private var actionError: String?
    @State private var stats: BackendClient.ModerationStatsDTO?
    @State private var statusFilter: FlagStatus? = nil
    @State private var pendingActionFlagID: UUID?

    private let statsColumns = [GridItem(.adaptive(minimum: 180), spacing: RFSpacing.md)]

    private var filteredFlags: [ModerationFlag] {
        guard let statusFilter else { return flags }
        return flags.filter { $0.status == statusFilter }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RFSpacing.xl) {
                LazyVGrid(columns: statsColumns, spacing: RFSpacing.md) {
                    StatCard(
                        label: "Intel Records",
                        value: stats.map { "\($0.intel_total)" } ?? "—",
                        symbol: "waveform.path.ecg",
                        accent: false
                    )
                    StatCard(
                        label: "Active Bounties",
                        value: stats.map { "\($0.bounty_total)" } ?? "—",
                        symbol: "scope",
                        accent: true
                    )
                    StatCard(
                        label: "Hunters Online",
                        value: stats.map { "\($0.hunter_total)" } ?? "—",
                        symbol: "person.crop.circle.badge.checkmark",
                        accent: false
                    )
                    StatCard(
                        label: "Pending Flags",
                        value: stats.map { "\($0.pending_flags)" } ?? "\(flags.filter { $0.status == .pending }.count)",
                        symbol: "exclamationmark.triangle.fill",
                        accent: false
                    )
                    StatCard(
                        label: "Quarantined",
                        value: stats.map { "\($0.quarantined_flags)" } ?? "\(flags.filter { $0.status == .quarantined }.count)",
                        symbol: "archivebox.fill",
                        accent: false
                    )
                    StatCard(
                        label: "Actioned",
                        value: stats.map { "\($0.actioned_flags)" } ?? "\(flags.filter { $0.status == .actioned }.count)",
                        symbol: "checkmark.seal.fill",
                        accent: false
                    )
                }

                filterStrip

                VStack(alignment: .leading, spacing: RFSpacing.md) {
                    HStack {
                        Eyebrow(text: "Grid Discrepancies")
                        Spacer()
                        Text("\(filteredFlags.count) ANOMALIES")
                            .font(.system(size: 10, weight: .black))
                            .tracking(1.3)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(RFColor.onSurface, in: Capsule())
                    }

                    if let actionError {
                        Text(actionError)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(RFColor.tertiary)
                            .padding(RFSpacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RFColor.tertiary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    }

                    if filteredFlags.isEmpty {
                        emptyState
                    } else {
                        ForEach(filteredFlags) { flag in
                            FlagCard(
                                flag: flag,
                                isProcessing: pendingActionFlagID == flag.id
                            ) { action in
                                Task { await apply(action, to: flag) }
                            }
                        }
                    }
                }
            }
            .padding(RFSpacing.lg)
        }
        .refreshable {
            await refresh()
        }
        .task { await refresh() }
        .background(RFColor.surface)
        .navigationTitle("Moderator")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: RFSpacing.sm) {
                FilterChip(
                    title: "All",
                    count: flags.count,
                    isActive: statusFilter == nil,
                    tint: RFColor.onSurface
                ) { statusFilter = nil }
                FilterChip(
                    title: "Pending",
                    count: flags.filter { $0.status == .pending }.count,
                    isActive: statusFilter == .pending,
                    tint: RFColor.tertiary
                ) { statusFilter = .pending }
                FilterChip(
                    title: "Quarantined",
                    count: flags.filter { $0.status == .quarantined }.count,
                    isActive: statusFilter == .quarantined,
                    tint: RFColor.outline
                ) { statusFilter = .quarantined }
                FilterChip(
                    title: "Actioned",
                    count: flags.filter { $0.status == .actioned }.count,
                    isActive: statusFilter == .actioned,
                    tint: RFColor.secondary
                ) { statusFilter = .actioned }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: RFSpacing.sm) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 36, weight: .black))
                .foregroundStyle(RFColor.secondary)
            Text("All clear")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(RFColor.onSurface)
            Text("No anomalies match the current filter.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .padding(RFSpacing.lg)
        .rfCardStyle(cornerRadius: 24)
    }

    @MainActor
    private func refresh() async {
        await appState.sync.syncAll(context: context)
        do {
            stats = try await appState.sync.client.fetchModerationStats()
        } catch {
            // Stats are best-effort — keep showing flag-derived counts.
        }
    }

    @MainActor
    private func apply(_ action: ModerationAction, to flag: ModerationFlag) async {
        let verb: String
        switch action {
        case .quarantine: verb = "quarantine"
        case .action: verb = "action"
        case .dismiss: verb = "dismiss"
        }
        pendingActionFlagID = flag.id
        defer { pendingActionFlagID = nil }
        do {
            _ = try await appState.sync.client.moderationAction(flagID: flag.id, action: verb)
            await refresh()
            actionError = nil
        } catch {
            actionError = "Backend rejected \(verb): \(error.localizedDescription)"
        }
    }
}

enum ModerationAction { case quarantine, action, dismiss }

private struct FilterChip: View {
    let title: String
    let count: Int
    let isActive: Bool
    let tint: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .black))
                    .tracking(1.3)
                Text("\(count)")
                    .font(.system(size: 10, weight: .black))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(isActive ? Color.white.opacity(0.25) : tint.opacity(0.12))
                    )
            }
            .foregroundStyle(isActive ? .white : tint)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(isActive ? tint : Color.clear)
            )
            .overlay(
                Capsule().stroke(tint.opacity(isActive ? 0 : 0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) filter, \(count) flags")
    }
}

private struct StatCard: View {
    let label: String
    let value: String
    let symbol: String
    let accent: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: RFSpacing.md) {
            HStack {
                IconBadge(symbol: symbol, tint: accent ? RFColor.primary : RFColor.onSurfaceVariant, size: 44)
                Spacer()
                Circle().fill(accent ? RFColor.primary : Color.clear).frame(width: 10, height: 10)
            }
            Spacer(minLength: 12)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .black))
                .tracking(1.4)
                .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.5))
            Text(value)
                .font(.system(size: 30, weight: .black))
                .foregroundStyle(RFColor.onSurface)
        }
        .padding(RFSpacing.lg)
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
        .rfCardStyle(cornerRadius: 28)
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(accent ? RFColor.primary : .clear, lineWidth: accent ? 3 : 0)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

private struct FlagCard: View {
    let flag: ModerationFlag
    let isProcessing: Bool
    let onAction: (ModerationAction) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: RFSpacing.md) {
            HStack(spacing: RFSpacing.md) {
                IconBadge(symbol: "exclamationmark.triangle.fill", tint: RFColor.tertiary, size: 48)
                VStack(alignment: .leading, spacing: 4) {
                    Text(flag.title)
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(RFColor.onSurface)
                    Text("Logged against Node \(flag.handle)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.6))
                    Text("\(flag.sightingCount) SIGHTING\(flag.sightingCount == 1 ? "" : "S") • \(flag.createdAt.rf_relative.uppercased())")
                        .font(.system(size: 9, weight: .black))
                        .tracking(1.2)
                        .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.5))
                    HStack(spacing: 6) {
                        TargetPill(label: targetLabel)
                        CategoryPill(category: flag.category)
                    }
                }
                Spacer()
                Text(flag.status.rawValue.uppercased())
                    .font(.system(size: 9, weight: .black))
                    .tracking(1.2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(statusTint(flag.status), in: Capsule())
            }
            Text("\"\(flag.reason)\"")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.6))
                .padding(.leading, RFSpacing.md)
                .overlay(
                    Rectangle().fill(RFColor.surfaceContainer).frame(width: 3),
                    alignment: .leading
                )
            if isProcessing {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Updating…")
                        .font(.system(size: 11, weight: .black))
                        .tracking(1.3)
                        .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.7))
                    Spacer()
                }
            } else if flag.status == .pending {
                HStack(spacing: RFSpacing.sm) {
                    RFSecondaryButton(title: "Dismiss", icon: "xmark") { onAction(.dismiss) }
                    RFSecondaryButton(title: "Quarantine", icon: "archivebox.fill") { onAction(.quarantine) }
                    RFDarkButton(title: "Action", icon: "checkmark") { onAction(.action) }
                }
            } else {
                RFSecondaryButton(title: "Reopen", icon: "arrow.uturn.backward") { onAction(.dismiss) }
            }
        }
        .padding(RFSpacing.lg)
        .rfCardStyle(cornerRadius: 28)
        .opacity(isProcessing ? 0.7 : 1.0)
    }

    private var targetLabel: String {
        if flag.bountyID != nil { return "BOUNTY" }
        if flag.reportID != nil { return "INTEL" }
        return "ORPHAN"
    }

    private func statusTint(_ s: FlagStatus) -> Color {
        switch s {
        case .pending: return RFColor.tertiary
        case .quarantined: return RFColor.outline
        case .actioned: return RFColor.secondary
        }
    }
}

private struct TargetPill: View {
    let label: String
    var body: some View {
        Text(label)
            .font(.system(size: 8, weight: .black))
            .tracking(1.4)
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(RFColor.onSurface, in: Capsule())
    }
}

private struct CategoryPill: View {
    let category: String
    var body: some View {
        let (text, tint) = mapping(category)
        Text(text)
            .font(.system(size: 8, weight: .black))
            .tracking(1.4)
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(tint.opacity(0.12), in: Capsule())
    }

    private func mapping(_ c: String) -> (String, Color) {
        switch c {
        case "language": return ("DANGEROUS LANG", RFColor.tertiary)
        case "duplicate": return ("DUPLICATE", RFColor.primary)
        default: return (c.uppercased(), RFColor.onSurfaceVariant)
        }
    }
}
