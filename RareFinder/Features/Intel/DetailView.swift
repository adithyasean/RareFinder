import SwiftUI
import SwiftData
import CoreLocation

struct DetailView: View {
    let bounty: Bounty
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Query private var profiles: [HunterProfile]

    @State private var showReportSheet = false
    @State private var scannerToast: String?
    @State private var isClaimed: Bool = false

    private var profile: HunterProfile? { profiles.first }
    private var verifyKey: String { "rf.verified.\(bounty.id.uuidString)" }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero
                content
                    .offset(y: -40)
                    .padding(.horizontal, RFSpacing.md)
            }
        }
        .background(RFColor.surface)
        .navigationTitle(bounty.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .ignoresSafeArea(edges: .top)
        .sheet(isPresented: $showReportSheet) {
            ReportFormView(prefilledBounty: bounty)
        }
        .onAppear {
            isClaimed = UserDefaults.standard.bool(forKey: verifyKey)
        }
    }

    private var shareText: String {
        "Rare Finder bounty — \(bounty.title) (\(bounty.district)). \(bounty.summary)"
    }

    private func launchScanner() {
        appState.location.requestAuthorization()
        appState.location.monitor(bounty: bounty)

        let appNote = AppNotification(
            title: "Scanner armed",
            body: "We'll alert you when you're within 50 m of \(bounty.title).",
            kind: .vicinity,
            symbol: "scope"
        )
        context.insert(appNote)
        try? context.save()

        Task {
            if !appState.notifications.authorized {
                await appState.notifications.requestAuthorization()
            }
            await appState.notifications.scheduleVicinityAlert(
                title: "Scanner armed: \(bounty.title)",
                body: "Tracking \(bounty.district). You'll get a vicinity alert when in range.",
                after: 1
            )
        }

        withAnimation { scannerToast = "Scanner armed for \(bounty.district)" }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { scannerToast = nil }
        }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [bounty.status.tint, RFColor.onSurface],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Image(systemName: bounty.symbol)
                .font(.system(size: 220, weight: .black))
                .foregroundStyle(.white.opacity(0.12))
                .offset(x: 60, y: -20)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: RFSpacing.sm) {
                HStack(spacing: 8) {
                    Tag(text: "Verified Rarity", tint: RFColor.secondary)
                    Tag(text: bounty.category.rawValue, tint: .white.opacity(0.2))
                }
                Text(bounty.title)
                    .font(.system(size: 38, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                Text(bounty.district.uppercased())
                    .font(.system(size: 11, weight: .black))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(RFSpacing.lg)
            .padding(.bottom, RFSpacing.lg)
            .padding(.top, RFSpacing.xl + 24)
        }
        .frame(height: 420)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 32, bottomTrailingRadius: 32, topTrailingRadius: 0))
        .overlay(alignment: .topLeading) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 48)
            .padding(.leading, RFSpacing.md)
            .accessibilityLabel("Back")
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: RFSpacing.lg) {
            HStack {
                HStack(spacing: RFSpacing.sm) {
                    IconBadge(symbol: bounty.symbol, tint: RFColor.primary, size: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("INTEL SCORE")
                            .font(.system(size: 9, weight: .black))
                            .tracking(1.5)
                            .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.5))
                        Text("#\(bounty.intelScore)")
                            .font(.system(size: 22, weight: .black))
                            .foregroundStyle(RFColor.onSurface)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("HIGH FREQUENCY")
                        .font(.system(size: 9, weight: .black))
                        .tracking(1.5)
                        .foregroundStyle(RFColor.secondary)
                    Text("Verified \(bounty.updatedAt.rf_relative)")
                        .font(.system(size: 10, weight: .black))
                        .tracking(1)
                        .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.5))
                }
            }
            .padding(RFSpacing.md)
            .rfCardStyle()

            VStack(alignment: .leading, spacing: RFSpacing.sm) {
                Eyebrow(text: "Intelligence Digest")
                Text(bounty.detail)
                    .font(.rfBody(16))
                    .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.85))
                    .lineSpacing(4)
            }

            geofenceCallout

            VStack(spacing: RFSpacing.sm) {
                RFDarkButton(title: "Launch Scanner", icon: "scope") {
                    launchScanner()
                }
                verifyButton
                HStack(spacing: RFSpacing.sm) {
                    RFSecondaryButton(title: "Add Intel", icon: "plus.circle.fill") {
                        showReportSheet = true
                    }
                    ShareLink(item: shareText) {
                        HStack(spacing: 10) {
                            Image(systemName: "square.and.arrow.up")
                            Text("DISPATCH")
                                .font(.system(size: 11, weight: .black))
                                .tracking(2.4)
                        }
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .foregroundStyle(RFColor.onSurface)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(.background)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(RFColor.outlineVariant.opacity(0.4), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dispatch — share this bounty")
                }
            }
            if let toast = scannerToast {
                Text(toast)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(RFColor.secondary)
                    .padding(.top, 4)
                    .transition(.opacity)
            }
        }
        .padding(RFSpacing.lg)
        .rfElevatedCard(cornerRadius: 36)
        .padding(.top, 16)
    }

    @ViewBuilder
    private var verifyButton: some View {
        if isClaimed {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                Text("VERIFIED — POINTS CLAIMED")
                    .font(.system(size: 11, weight: .black))
                    .tracking(2.4)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(RFColor.secondary)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(RFColor.secondary.opacity(0.12))
            )
            .accessibilityLabel("Already verified. Trust Points awarded.")
        } else {
            RFSecondaryButton(title: "Verify Bounty (+\(verifyAward) pts)", icon: "checkmark.shield.fill") {
                verifyBounty()
            }
        }
    }

    private var verifyAward: Int {
        EconomyService.pointsForReport(quality: .verification, isGeofenceVerified: true)
    }

    private func verifyBounty() {
        appState.location.requestAuthorization()
        appState.location.start()

        guard let here = appState.location.currentLocation else {
            showToast("Acquiring GPS… try again in a moment.")
            return
        }

        let inside = LocationService.isWithinGeofence(
            userCoordinate: here.coordinate,
            targetCoordinate: bounty.coordinate
        )
        guard inside else {
            showToast("Move within 50 m of \(bounty.district) to verify.")
            return
        }

        let points = verifyAward
        bounty.verifiedCount += 1
        bounty.upvotes += 1
        bounty.updatedAt = .now
        profile?.points += points
        profile?.verifications += 1

        let receipt = IntelReport(
            hunterName: profile?.displayName ?? "You",
            hunterSeed: profile?.avatarSeed,
            note: "Geofence verified — proof of presence within 50 m.",
            status: bounty.status,
            district: bounty.district,
            coordinate: bounty.coordinate,
            symbol: "checkmark.shield.fill",
            pointsAwarded: points,
            bounty: bounty
        )
        context.insert(receipt)

        let appNote = AppNotification(
            title: "Verified +\(points) Trust XP",
            body: "Proof-of-presence confirmed at \(bounty.title).",
            kind: .reward,
            symbol: "checkmark.seal.fill"
        )
        context.insert(appNote)
        try? context.save()

        UserDefaults.standard.set(true, forKey: verifyKey)
        isClaimed = true
        showToast("Verified — +\(points) Trust Points awarded.")
    }

    private func showToast(_ text: String) {
        withAnimation { scannerToast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            withAnimation { scannerToast = nil }
        }
    }

    private var geofenceCallout: some View {
        HStack(spacing: RFSpacing.md) {
            IconBadge(symbol: "location.viewfinder", tint: RFColor.primary, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("GEOFENCED ZONE")
                    .font(.system(size: 9, weight: .black))
                    .tracking(1.5)
                    .foregroundStyle(RFColor.primary)
                Text("Verify in person within 50 m to claim bounty points.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.8))
            }
        }
        .padding(RFSpacing.md)
        .background(RFColor.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
