import SwiftUI

struct OnboardingFlow: View {
    @State private var step: Int = 0
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            RFColor.surface.ignoresSafeArea()
            content
                .animation(.spring(duration: 0.4), value: step)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case 0:
            OnboardingPage(
                eyebrow: "Locate The Rare",
                title: "Crowdsourced Radar For\nScarce Goods",
                copy: "Rare Finder turns shortages into a treasure hunt. Every hunter on the grid pushes real-time intel the moment scarce items surface.",
                symbol: "dot.radiowaves.left.and.right",
                palette: [RFColor.primary, RFColor.primaryDeep],
                pageIndex: 0,
                pageCount: 4,
                primaryTitle: "Continue",
                onPrimary: { step = 1 },
                onSkip: { step = 3 }
            )
        case 1:
            OnboardingPage(
                eyebrow: "Earn Trust Points",
                title: "Verify Intel, Earn\nReputation",
                copy: "Submit verified sightings, upvote reliable hunters, and stake Trust Points on your own bounty requests to rise above the noise.",
                symbol: "trophy.fill",
                palette: [RFColor.secondary, RFColor.primary],
                pageIndex: 1,
                pageCount: 4,
                primaryTitle: "Continue",
                onPrimary: { step = 2 },
                onSkip: { step = 3 }
            )
        case 2:
            OnboardingPermissions(
                onContinue: { step = 3 }
            )
        default:
            OnboardingAuth(
                onFinish: { appState.completeOnboarding() }
            )
        }
    }
}

private struct OnboardingPage: View {
    let eyebrow: String
    let title: String
    let copy: String
    let symbol: String
    let palette: [Color]
    let pageIndex: Int
    let pageCount: Int
    let primaryTitle: String
    let onPrimary: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip", action: onSkip)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.7))
                    .padding(.top, RFSpacing.md)
                    .padding(.trailing, RFSpacing.lg)
                    .accessibilityLabel("Skip onboarding")
            }

            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .fill(palette[0].opacity(0.15))
                    .frame(width: 260, height: 260)
                    .blur(radius: 20)
                Image(systemName: symbol)
                    .font(.system(size: 120, weight: .black))
                    .foregroundStyle(LinearGradient(colors: palette, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, RFSpacing.xl)

            VStack(alignment: .leading, spacing: RFSpacing.md) {
                Eyebrow(text: eyebrow, color: RFColor.primary)
                Text(title)
                    .font(.system(size: 38, weight: .black))
                    .foregroundStyle(RFColor.onSurface)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                Text(copy)
                    .font(.rfBody(16))
                    .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.75))
                    .lineSpacing(4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, RFSpacing.lg)

            Spacer(minLength: RFSpacing.xl)

            PageDots(count: pageCount, index: pageIndex)
                .padding(.bottom, RFSpacing.md)

            RFPrimaryButton(title: primaryTitle, icon: "arrow.right", action: onPrimary)
                .padding(.horizontal, RFSpacing.lg)
                .padding(.bottom, RFSpacing.xl)
        }
    }
}

private struct PageDots: View {
    let count: Int
    let index: Int
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == index ? RFColor.primary : RFColor.outlineVariant.opacity(0.5))
                    .frame(width: i == index ? 24 : 8, height: 8)
                    .animation(.spring, value: index)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Page \(index + 1) of \(count)")
    }
}

private struct OnboardingPermissions: View {
    let onContinue: () -> Void
    @Environment(AppState.self) private var appState
    @State private var locationRequested = false
    @State private var notifRequested = false

    var body: some View {
        VStack(alignment: .leading, spacing: RFSpacing.lg) {
            HStack {
                Spacer()
            }
            Spacer(minLength: RFSpacing.lg)
            VStack(alignment: .leading, spacing: RFSpacing.sm) {
                Eyebrow(text: "Grid Permissions", color: RFColor.primary)
                Text("Tune Your Scanner")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(RFColor.onSurface)
                Text("Rare Finder uses your coordinates and push alerts to notify you the moment scarce items surface nearby.")
                    .font(.rfBody())
                    .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.75))
            }
            .padding(.horizontal, RFSpacing.lg)

            VStack(spacing: RFSpacing.md) {
                PermissionRow(
                    symbol: "location.fill",
                    title: "Location",
                    subtitle: "Surface bounties in your 15km sector and unlock geofenced proof-of-presence.",
                    actionTitle: locationRequested ? "Requested" : "Enable",
                    done: locationRequested
                ) {
                    appState.location.requestAuthorization()
                    locationRequested = true
                }
                PermissionRow(
                    symbol: "bell.badge.fill",
                    title: "Notifications",
                    subtitle: "Get vicinity alerts when a requested item appears within reach.",
                    actionTitle: notifRequested ? "Requested" : "Enable",
                    done: notifRequested
                ) {
                    Task {
                        await appState.notifications.requestAuthorization()
                        notifRequested = true
                    }
                }
            }
            .padding(.horizontal, RFSpacing.lg)

            Spacer()

            RFPrimaryButton(title: "Continue", icon: "arrow.right", action: onContinue)
                .padding(.horizontal, RFSpacing.lg)
                .padding(.bottom, RFSpacing.xl)
        }
    }
}

private struct PermissionRow: View {
    let symbol: String
    let title: String
    let subtitle: String
    let actionTitle: String
    let done: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: RFSpacing.md) {
            IconBadge(symbol: symbol, tint: RFColor.primary, size: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(RFColor.onSurface)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button(action: action) {
                Text(actionTitle.uppercased())
                    .font(.system(size: 10, weight: .black))
                    .tracking(1.5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .foregroundStyle(done ? RFColor.secondary : .white)
                    .background(
                        Capsule().fill(done ? RFColor.secondaryContainer.opacity(0.4) : RFColor.onSurface)
                    )
            }
            .buttonStyle(.plain)
            .disabled(done)
        }
        .padding(RFSpacing.md)
        .rfCardStyle(cornerRadius: RFRadius.md)
        .accessibilityElement(children: .combine)
    }
}

private struct OnboardingAuth: View {
    let onFinish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: RFSpacing.lg) {
            Spacer(minLength: RFSpacing.xl)

            VStack(alignment: .center, spacing: RFSpacing.sm) {
                HeroIconArt(symbol: "dot.radiowaves.left.and.right", palette: [RFColor.primary, RFColor.primaryDeep])
                    .frame(width: 140, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 36, style: .continuous)
                            .stroke(RFColor.outlineVariant.opacity(0.3), lineWidth: 1)
                    )
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: RFSpacing.sm) {
                Eyebrow(text: "Join The Grid", color: RFColor.primary)
                Text("Welcome, Hunter")
                    .font(.system(size: 38, weight: .black))
                    .foregroundStyle(RFColor.onSurface)
                Text("Sign in to sync verifications, earn reputation, and unlock tier-gated rewards.")
                    .font(.rfBody())
                    .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.75))
            }
            .padding(.horizontal, RFSpacing.lg)

            Spacer()

            VStack(spacing: RFSpacing.sm) {
                RFDarkButton(title: "Continue with Apple", icon: "apple.logo", action: onFinish)
                RFSecondaryButton(title: "Use Email", icon: "envelope.fill", action: onFinish)
                Button(action: onFinish) {
                    Text("Enter As Guest")
                        .font(.system(size: 11, weight: .black))
                        .tracking(2)
                        .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.6))
                        .padding(.top, 8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, RFSpacing.lg)
            .padding(.bottom, RFSpacing.xl)
        }
    }
}

#Preview {
    OnboardingFlow()
        .environment(AppState())
}
