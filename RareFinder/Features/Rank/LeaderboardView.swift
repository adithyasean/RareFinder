import SwiftUI
import SwiftData

struct LeaderboardEntry: Identifiable, Hashable {
    let id: UUID
    let displayName: String
    let handle: String
    let avatarSeed: String
    let points: Int
    let rank: Int
    let verifications: Int
    let streak: Int
    
    var rankColor: Color {
        switch rank {
        case 1: return RFColor.primary
        case 2: return RFColor.outline
        case 3: return RFColor.primaryDeep
        default: return RFColor.onSurfaceVariant.opacity(0.5)
        }
    }
    
    var rankIcon: String {
        switch rank {
        case 1: return "crown.fill"
        case 2: return "medal.fill"
        case 3: return "trophy.fill"
        default: return "star.fill"
        }
    }
}

struct LeaderboardView: View {
    @Query private var profiles: [HunterProfile]
    @Environment(AppState.self) private var appState

    @State private var entries: [LeaderboardEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var currentHunterID: UUID? { profiles.first?.id }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RFSpacing.lg) {
                header

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(RFColor.tertiary)
                        .padding(RFSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RFColor.tertiary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                }

                if entries.isEmpty && isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else if entries.isEmpty {
                    Text("No rankings available yet. Start verifying intel to appear on the grid.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.7))
                        .padding(RFSpacing.lg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .rfCardStyle(cornerRadius: 24)
                } else {
                    if let podium = podiumSlice {
                        podiumStrip(podium)
                            .padding(.bottom, RFSpacing.md)
                    }
                    
                    if entries.count > 3 {
                        rankList
                    }
                }
            }
            .padding(RFSpacing.lg)
        }
        .background(RFColor.surface)
        .navigationTitle("Leaderboard")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await load() }
        .refreshable { await load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(text: "Global Verification Grid", color: RFColor.primary)
            Text("Top Hunters")
                .font(.system(size: 30, weight: .black))
                .foregroundStyle(RFColor.onSurface)
            Text("Ranked by total XP earned across the network.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.7))
        }
    }

    private var podiumSlice: ArraySlice<LeaderboardEntry>? {
        guard entries.count >= 3 else { return nil }
        return entries.prefix(3)
    }

    private func podiumStrip(_ top: ArraySlice<LeaderboardEntry>) -> some View {
        HStack(alignment: .bottom, spacing: RFSpacing.sm) {
            ForEach(podiumOrder(top), id: \.id) { entry in
                PodiumTile(
                    entry: entry,
                    height: heightForRank(entry.rank),
                    isCurrentUser: entry.id == currentHunterID
                )
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func podiumOrder(_ top: ArraySlice<LeaderboardEntry>) -> [LeaderboardEntry] {
        let arr = Array(top)
        guard arr.count == 3 else { return arr }
        return [arr[1], arr[0], arr[2]]
    }

    private func heightForRank(_ rank: Int) -> CGFloat {
        switch rank {
        case 1: return 190
        case 2: return 160
        default: return 145
        }
    }

    private var rankList: some View {
        VStack(alignment: .leading, spacing: RFSpacing.md) {
            Eyebrow(text: "Grid Standings", color: RFColor.onSurfaceVariant.opacity(0.5))
            
            VStack(spacing: RFSpacing.sm) {
                ForEach(Array(entries.dropFirst(3))) { entry in
                    LeaderboardRow(entry: entry, isCurrentUser: entry.id == currentHunterID)
                }
            }
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let dtos = try await appState.sync.client.fetchLeaderboard()
            entries = dtos.enumerated().map { index, dto in
                LeaderboardEntry(
                    id: dto.id,
                    displayName: dto.display_name,
                    handle: dto.handle,
                    avatarSeed: dto.avatar_seed,
                    points: dto.points,
                    rank: index + 1,
                    verifications: dto.verifications,
                    streak: dto.streak
                )
            }
            errorMessage = nil
        } catch {
            errorMessage = "Could not load leaderboard: \(error.localizedDescription)"
        }
    }
}

private struct PodiumTile: View {
    let entry: LeaderboardEntry
    let height: CGFloat
    let isCurrentUser: Bool

    var body: some View {
        VStack(spacing: RFSpacing.sm) {
            ZStack(alignment: .topTrailing) {
                AvatarView(seed: entry.avatarSeed, size: 56)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(entry.rankColor, lineWidth: 3)
                    )
                Image(systemName: entry.rankIcon)
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(entry.rankColor, in: Circle())
                    .offset(x: 6, y: -6)
            }
            Text(entry.displayName)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(RFColor.onSurface)
                .lineLimit(1)
            Text("\(entry.points) XP")
                .font(.system(size: 11, weight: .black))
                .tracking(1.2)
                .foregroundStyle(entry.rankColor)
            Spacer(minLength: RFSpacing.xs)
            Text("#\(entry.rank)")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: height * 0.4)
                .background(entry.rankColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(.top, RFSpacing.md)
        .padding(.horizontal, RFSpacing.sm)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .rfCardStyle(cornerRadius: 24)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(isCurrentUser ? entry.rankColor : .clear, lineWidth: isCurrentUser ? 3 : 0)
        )
    }
}

private struct LeaderboardRow: View {
    let entry: LeaderboardEntry
    let isCurrentUser: Bool

    var body: some View {
        HStack(spacing: RFSpacing.md) {
            Text("\(entry.rank)")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(entry.rankColor)
                .frame(width: 32, alignment: .leading)

            AvatarView(seed: entry.avatarSeed, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.displayName)
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(RFColor.onSurface)
                    if isCurrentUser {
                        Text("YOU")
                            .font(.system(size: 8, weight: .black))
                            .tracking(1.2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .foregroundStyle(.white)
                            .background(RFColor.primary, in: Capsule())
                    }
                }
                Text(entry.handle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.6))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.points)")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(RFColor.onSurface)
                Text("XP")
                    .font(.system(size: 9, weight: .black))
                    .tracking(1.2)
                    .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.5))
            }
        }
        .padding(RFSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isCurrentUser ? RFColor.primary.opacity(0.06) : Color.clear)
        )
        .rfCardStyle(cornerRadius: 18)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isCurrentUser ? entry.rankColor.opacity(0.6) : .clear, lineWidth: isCurrentUser ? 1.5 : 0)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(entry.rank): \(entry.displayName), \(entry.points) XP")
    }
}
