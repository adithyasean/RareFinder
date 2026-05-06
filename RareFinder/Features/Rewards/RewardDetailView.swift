import SwiftUI
import SwiftData

struct RewardDetailView: View {
    let reward: Reward
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [HunterProfile]
    @State private var showRedeemAlert = false
    @State private var redeemMessage = ""

    var profile: HunterProfile? { profiles.first }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RFSpacing.lg) {
                hero
                VStack(alignment: .leading, spacing: RFSpacing.md) {
                    Text(reward.title)
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(RFColor.onSurface)
                    Text(reward.detail)
                        .font(.rfBody())
                        .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.75))

                    HStack(spacing: RFSpacing.sm) {
                        statPane(label: "Asset Cost", value: "\(reward.cost) PTS", tint: RFColor.primary)
                        statPane(label: "Your Credit", value: "\(profile?.points ?? 0) PTS", tint: RFColor.onSurface)
                    }

                    perks

                    redeemControl
                }
                .padding(RFSpacing.lg)
                .rfElevatedCard(cornerRadius: 32)
            }
            .padding(RFSpacing.md)
        }
        .background(RFColor.surface)
        .navigationTitle(reward.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert("Redemption", isPresented: $showRedeemAlert) {
            Button("OK") { dismiss() }
        } message: {
            Text(redeemMessage)
        }
    }

    private var hero: some View {
        ZStack {
            LinearGradient(colors: [RFColor.primary, RFColor.primaryDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: reward.symbol)
                .font(.system(size: 160, weight: .black))
                .foregroundStyle(.white.opacity(0.2))
            Tag(text: "Certified Drop", tint: RFColor.secondary)
                .padding(.top, 40)
                .padding(.leading, RFSpacing.md)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }

    private func statPane(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .black))
                .tracking(1.4)
                .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.5))
            Text(value)
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(RFSpacing.md)
        .background(RFColor.surfaceContainerLow, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var perks: some View {
        VStack(spacing: RFSpacing.sm) {
            perkRow(symbol: "clock.fill", title: "Instant Activation", subtitle: "Syncs synchronously with your grid")
            perkRow(symbol: "dot.radiowaves.left.and.right", title: "Grid-Wide Applied", subtitle: "Covers your active 15km sector")
        }
    }

    private func perkRow(symbol: String, title: String, subtitle: String) -> some View {
        HStack(spacing: RFSpacing.md) {
            IconBadge(symbol: symbol, tint: RFColor.primary, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(RFColor.onSurface)
                Text(subtitle.uppercased())
                    .font(.system(size: 9, weight: .black))
                    .tracking(1.4)
                    .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.5))
            }
            Spacer()
        }
        .padding(RFSpacing.md)
        .rfCardStyle()
    }

    @ViewBuilder
    private var redeemControl: some View {
        if reward.isClaimed {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                Text("ALREADY CLAIMED")
                    .font(.system(size: 11, weight: .black))
                    .tracking(2.4)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.6))
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(RFColor.surfaceContainer)
            )
            .accessibilityLabel("Already claimed on \(reward.claimedAt?.formatted(date: .abbreviated, time: .shortened) ?? "")")
        } else {
            RFDarkButton(title: "Redeem Intel Access", icon: "bolt.fill", action: redeem)
        }
    }

    private func redeem() {
        guard let profile else { return }
        guard !reward.isClaimed else {
            redeemMessage = "This reward has already been claimed."
            showRedeemAlert = true
            return
        }
        if let newBalance = EconomyService.redeem(balance: profile.points, cost: reward.cost) {
            profile.points = newBalance
            reward.claimedAt = .now
            try? context.save()
            redeemMessage = "Access granted. \(reward.title) is now active."
        } else {
            redeemMessage = "Insufficient Trust Points. Earn \(reward.cost - profile.points) more to unlock."
        }
        showRedeemAlert = true
    }
}
