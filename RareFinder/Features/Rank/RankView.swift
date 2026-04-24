import SwiftUI
import SwiftData

struct RankView: View {
    @Query private var profiles: [HunterProfile]
    @Query(sort: [SortDescriptor(\IntelReport.createdAt, order: .reverse)]) private var reports: [IntelReport]
    @Environment(AppState.self) private var appState

    var profile: HunterProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: RFSpacing.lg) {
                    if let profile {
                        header(profile: profile)
                        xpEngine(profile: profile)
                        stats(profile: profile)
                    }
                    recent
                }
                .padding(RFSpacing.lg)
            }
            .background(RFColor.surface)
            .navigationTitle("Hunter Profile")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .secondaryAction) {
                    NavigationLink {
                        RewardsStoreView()
                    } label: {
                        Label("Rewards", systemImage: "gift.fill")
                    }
                }
                if profile?.isModerator == true {
                    ToolbarItem(placement: .secondaryAction) {
                        NavigationLink {
                            ModeratorView()
                        } label: {
                            Label("Moderator", systemImage: "checkmark.shield.fill")
                        }
                    }
                }
            }
        }
    }

    private func header(profile: HunterProfile) -> some View {
        VStack(spacing: RFSpacing.sm) {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(seed: profile.avatarSeed, size: 120)
                    .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(.white, lineWidth: 4))
                    .shadow(color: .black.opacity(0.1), radius: 10, y: 6)
                Text(profile.tier.rawValue.uppercased())
                    .font(.system(size: 9, weight: .black))
                    .tracking(1.5)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .foregroundStyle(.white)
                    .background(RFColor.onSurface, in: Capsule())
                    .offset(x: 8, y: 8)
            }
            Text(profile.displayName)
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(RFColor.onSurface)
            HStack(spacing: 6) {
                Image(systemName: "trophy.fill").foregroundStyle(RFColor.primary)
                Text("VERIFICATION RANK #\(profile.rank)")
                    .font(.system(size: 10, weight: .black))
                    .tracking(1.5)
                    .foregroundStyle(RFColor.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(RFColor.primary.opacity(0.08), in: Capsule())
        }
    }

    private func xpEngine(profile: HunterProfile) -> some View {
        VStack(alignment: .leading, spacing: RFSpacing.md) {
            HStack {
                Text("HUNTER XP ENGINE")
                    .font(.system(size: 10, weight: .black))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Image(systemName: "bolt.fill").foregroundStyle(RFColor.primary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(profile.points)")
                    .font(.system(size: 44, weight: .black))
                    .foregroundStyle(.white)
                Text("POINTS")
                    .font(.system(size: 12, weight: .black))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.4))
            }
            ProgressView(value: EconomyService.tierProgress(points: profile.points))
                .tint(RFColor.primary)
                .background(Color.white.opacity(0.08), in: Capsule())
            HStack {
                Text("CURRENT: \(profile.tier.rawValue.uppercased())")
                    .font(.system(size: 9, weight: .black))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
                Text("NEXT TIER")
                    .font(.system(size: 9, weight: .black))
                    .tracking(1.5)
                    .foregroundStyle(RFColor.primary)
            }
        }
        .padding(RFSpacing.lg)
        .background(RFColor.onSurface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func stats(profile: HunterProfile) -> some View {
        HStack(spacing: RFSpacing.sm) {
            StatTile(title: "Verifications", value: "\(profile.verifications)", symbol: "checkmark.seal.fill", tint: RFColor.secondary)
            StatTile(title: "Streak", value: "\(profile.streak)d", symbol: "flame.fill", tint: RFColor.primary)
            StatTile(title: "Tier", value: profile.tier.rawValue.capitalized, symbol: profile.tier.accent, tint: RFColor.primaryDeep)
        }
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Eyebrow(text: "Recent Transmissions")
                .padding(.top, RFSpacing.md)
            ForEach(reports.prefix(4)) { r in
                HStack(spacing: RFSpacing.sm) {
                    IconBadge(symbol: r.symbol, tint: r.status.tint, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.note).font(.system(size: 13, weight: .medium)).lineLimit(2)
                            .foregroundStyle(RFColor.onSurface)
                        Text(r.createdAt.rf_relative.uppercased())
                            .font(.system(size: 9, weight: .black))
                            .tracking(1.2)
                            .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.5))
                    }
                    Spacer()
                    Text("+\(r.pointsAwarded)")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(RFColor.primary)
                }
                .padding(RFSpacing.sm)
                .rfCardStyle(cornerRadius: 18)
            }
        }
    }
}

private struct StatTile: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(RFColor.onSurface)
            Text(title.uppercased())
                .font(.system(size: 9, weight: .black))
                .tracking(1.4)
                .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(RFSpacing.md)
        .rfCardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}
