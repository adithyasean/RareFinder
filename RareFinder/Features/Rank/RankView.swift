import SwiftUI
import SwiftData

struct RankView: View {
    @Query private var profiles: [HunterProfile]
    @Query(sort: [SortDescriptor(\IntelReport.createdAt, order: .reverse)]) private var reports: [IntelReport]
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @State private var showLogoutConfirm = false
    @State private var showAuthSheet = false

    var profile: HunterProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: RFSpacing.lg) {
                    if let profile {
                        header(profile: profile)
                        xpEngine(profile: profile)
                        stats(profile: profile)
                        quickLinks(profile: profile)
                    }
                    recent
                    accountActions
                }
                .padding(RFSpacing.lg)
            }
            .background(RFColor.surface)
            .navigationTitle("Hunter Profile")
            .rfUnifiedToolbar(primary: .settings, isModerator: profile?.isModerator == true)
        }
    }

    private var accountActions: some View {
        VStack(spacing: RFSpacing.sm) {
            if appState.auth.isAuthenticated {
                Button(role: .destructive) {
                    showLogoutConfirm = true
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Log Out")
                            .font(.system(size: 13, weight: .black))
                            .tracking(1.5)
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .foregroundStyle(.red)
                    .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profile_logout")
                .confirmationDialog("Log out of Rare Finder?", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
                    Button("Log Out", role: .destructive) {
                        Task {
                            await appState.logout(context: context)
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                }
            } else {
                Button {
                    showAuthSheet = true
                } label: {
                    HStack {
                        Image(systemName: "key.fill")
                        Text("Log In Or Sign Up")
                            .font(.system(size: 13, weight: .black))
                            .tracking(1.5)
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .foregroundStyle(.white)
                    .background(RFColor.primaryGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profile_login")
                .sheet(isPresented: $showAuthSheet) {
                    NavigationStack {
                        AuthView {
                            showAuthSheet = false
                            Task { await appState.sync.syncAll(context: context) }
                        }
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { showAuthSheet = false }
                            }
                        }
                    }
                }
            }
        }
        .padding(.top, RFSpacing.sm)
    }

    private func quickLinks(profile: HunterProfile) -> some View {
        VStack(spacing: RFSpacing.sm) {
            NavigationLink {
                LeaderboardView()
            } label: {
                QuickLinkRow(
                    icon: "trophy.fill",
                    title: "Global Leaderboard",
                    subtitle: "Rank #\(profile.rank) on the verification grid",
                    tint: RFColor.primary
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                RewardsStoreView()
            } label: {
                QuickLinkRow(
                    icon: "gift.fill",
                    title: "Rewards Store",
                    subtitle: "Spend XP on supply drops & boosts",
                    tint: RFColor.secondary
                )
            }
            .buttonStyle(.plain)

            if profile.isModerator {
                NavigationLink {
                    ModeratorView()
                } label: {
                    QuickLinkRow(
                        icon: "checkmark.shield.fill",
                        title: "Moderator Console",
                        subtitle: "Review flagged nodes & grid anomalies",
                        tint: RFColor.tertiary
                    )
                }
                .buttonStyle(.plain)
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

private struct QuickLinkRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color
    var body: some View {
        HStack(spacing: RFSpacing.md) {
            IconBadge(symbol: icon, tint: tint, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(RFColor.onSurface)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.6))
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.4))
        }
        .padding(RFSpacing.md)
        .rfCardStyle(cornerRadius: 18)
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
