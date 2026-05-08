import SwiftUI
import SwiftData

struct RewardsStoreView: View {
    @Query(sort: [SortDescriptor(\Reward.cost, order: .forward)]) private var rewards: [Reward]
    @Query private var profiles: [HunterProfile]
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    var profile: HunterProfile? { profiles.first }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RFSpacing.xl) {
                ConnectionBanner(connection: appState.sync.connection) {
                    Task { await appState.sync.syncAll(context: context) }
                }
                hunterCredit
                supplyReserves
                tierPromo
            }
            .padding(RFSpacing.lg)
        }
        .refreshable {
            await appState.sync.syncAll(context: context)
        }
        .background(RFColor.surface)
        .navigationTitle("Rewards Store")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var hunterCredit: some View {
        VStack(spacing: RFSpacing.sm) {
            Eyebrow(text: "Hunter Credit")
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(profile?.points ?? 0)")
                    .font(.system(size: 72, weight: .black))
                    .foregroundStyle(RFColor.onSurface)
                Text("PTS")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(RFColor.primary)
            }
            HStack(spacing: 8) {
                Image(systemName: profile?.tier.accent ?? "trophy.fill").foregroundStyle(RFColor.primary)
                Text((profile?.tier.title ?? "Gold Hunter").uppercased())
                    .font(.system(size: 10, weight: .black))
                    .tracking(1.4)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(RFColor.onSurface, in: Capsule())
        }
        .frame(maxWidth: .infinity)
    }

    private var supplyReserves: some View {
        VStack(alignment: .leading, spacing: RFSpacing.md) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Supply Reserves")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(RFColor.onSurface)
                    Text("AVAILABLE GRID REWARDS")
                        .font(.system(size: 9, weight: .black))
                        .tracking(1.5)
                        .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.5))
                }
                Spacer()
                Text("CATALOG")
                    .font(.system(size: 10, weight: .black))
                    .tracking(1.5)
                    .foregroundStyle(RFColor.primary)
            }

            VStack(spacing: RFSpacing.md) {
                ForEach(rewards) { reward in
                    NavigationLink {
                        RewardDetailView(reward: reward)
                    } label: {
                        RewardRow(reward: reward, canAfford: (profile?.points ?? 0) >= reward.cost)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var tierPromo: some View {
        VStack(alignment: .leading, spacing: RFSpacing.md) {
            HStack(spacing: 8) {
                Circle().fill(RFColor.primary).frame(width: 10, height: 10)
                Text("ELITE MATRIX PROPAGATION")
                    .font(.system(size: 10, weight: .black))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.5))
            }
            Text("Access Platinum Tier")
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(.white)
            let needed = max(0, 2000 - (profile?.points ?? 0))
            Text("Collect \(needed) more points to unlock regional neural scanning and zero-latency alerts.")
                .font(.rfBody())
                .foregroundStyle(.white.opacity(0.6))
            ProgressView(value: EconomyService.tierProgress(points: profile?.points ?? 0))
                .tint(RFColor.primary)
        }
        .padding(RFSpacing.lg)
        .background(RFColor.onSurface, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
    }
}

private struct RewardRow: View {
    let reward: Reward
    let canAfford: Bool

    var body: some View {
        HStack(spacing: RFSpacing.md) {
            IconBadge(symbol: reward.symbol, tint: canAfford ? RFColor.primary : RFColor.outline, size: 64)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(reward.title)
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(RFColor.onSurface)
                    Spacer()
                    Text("\(reward.cost) PTS")
                        .font(.system(size: 10, weight: .black))
                        .tracking(1.2)
                        .foregroundStyle(canAfford ? RFColor.primary : RFColor.outline)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((canAfford ? RFColor.primary : RFColor.outline).opacity(0.1), in: Capsule())
                }
                Text(reward.summary)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.6))
                    .lineLimit(2)
            }
        }
        .padding(RFSpacing.md)
        .rfCardStyle(cornerRadius: 28)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(reward.title), costs \(reward.cost) points, \(canAfford ? "affordable" : "insufficient balance")")
    }
}
