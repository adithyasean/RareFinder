import SwiftUI
import SwiftData

struct ModeratorView: View {
    @Query(sort: [SortDescriptor(\ModerationFlag.createdAt, order: .reverse)]) private var flags: [ModerationFlag]
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @State private var actionError: String?

    private let statsColumns = [GridItem(.adaptive(minimum: 180), spacing: RFSpacing.md)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RFSpacing.xl) {
                LazyVGrid(columns: statsColumns, spacing: RFSpacing.md) {
                    StatCard(label: "Intelligence Records / hr", value: "142", symbol: "waveform.path.ecg", accent: false)
                    StatCard(label: "Neural Mesh Pulse", value: "8.4k", symbol: "dot.radiowaves.left.and.right", accent: true)
                    StatCard(label: "Unverified Nodes", value: "\(flags.filter { $0.status == .pending }.count)", symbol: "person.crop.circle.badge.questionmark", accent: false)
                }

                VStack(alignment: .leading, spacing: RFSpacing.md) {
                    HStack {
                        Eyebrow(text: "Grid Discrepancies")
                        Spacer()
                        Text("\(flags.count) ANOMALIES LOGGED")
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

                    ForEach(flags) { flag in
                        FlagCard(flag: flag) { action in
                            Task { await apply(action, to: flag) }
                        }
                    }
                }
            }
            .padding(RFSpacing.lg)
        }
        .refreshable {
            await appState.sync.syncAll(context: context)
        }
        .background(RFColor.surface)
        .navigationTitle("Moderator")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    @MainActor
    private func apply(_ action: ModerationAction, to flag: ModerationFlag) async {
        let verb: String
        switch action {
        case .quarantine: verb = "quarantine"
        case .action: verb = "action"
        }
        do {
            _ = try await appState.sync.client.moderationAction(flagID: flag.id, action: verb)
            await appState.sync.syncAll(context: context)
            actionError = nil
        } catch {
            actionError = "Backend rejected \(verb): \(error.localizedDescription)"
        }
    }
}

enum ModerationAction { case quarantine, action }

private struct StatCard: View {
    let label: String
    let value: String
    let symbol: String
    let accent: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: RFSpacing.md) {
            HStack {
                IconBadge(symbol: symbol, tint: accent ? RFColor.primary : RFColor.onSurfaceVariant, size: 48)
                Spacer()
                Circle().fill(accent ? RFColor.primary : Color.clear).frame(width: 10, height: 10)
            }
            Spacer(minLength: 20)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .black))
                .tracking(1.4)
                .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.5))
            Text(value)
                .font(.system(size: 34, weight: .black))
                .foregroundStyle(RFColor.onSurface)
        }
        .padding(RFSpacing.lg)
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .leading)
        .rfCardStyle(cornerRadius: 32)
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(accent ? RFColor.primary : .clear, lineWidth: accent ? 3 : 0)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

private struct FlagCard: View {
    let flag: ModerationFlag
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
            HStack(spacing: RFSpacing.sm) {
                RFSecondaryButton(title: "Quarantine", icon: "archivebox.fill") { onAction(.quarantine) }
                RFDarkButton(title: "Action Node", icon: "checkmark") { onAction(.action) }
            }
        }
        .padding(RFSpacing.lg)
        .rfCardStyle(cornerRadius: 28)
    }

    private func statusTint(_ s: FlagStatus) -> Color {
        switch s {
        case .pending: return RFColor.tertiary
        case .quarantined: return RFColor.outline
        case .actioned: return RFColor.secondary
        }
    }
}
