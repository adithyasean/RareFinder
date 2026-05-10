import SwiftUI
import CoreLocation

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

    private var isLocationDone: Bool {
        #if os(macOS)
        appState.location.authorization == .authorizedAlways || locationRequested
        #else
        appState.location.authorization == .authorizedAlways || appState.location.authorization == .authorizedWhenInUse || locationRequested
        #endif
    }

    private var isNotifDone: Bool {
        appState.notifications.authorized || notifRequested
    }

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
                
                if isLocationDone && isNotifDone {
                    Text("The grid is active. Rare Finder already has the necessary access to sync your scanner.")
                        .font(.rfBody())
                        .foregroundStyle(RFColor.secondary)
                        .padding(.vertical, 4)
                } else {
                    Text("Rare Finder uses your coordinates and push alerts to notify you the moment scarce items surface nearby.")
                        .font(.rfBody())
                        .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.75))
                }
            }
            .padding(.horizontal, RFSpacing.lg)

            VStack(spacing: RFSpacing.md) {
                PermissionRow(
                    symbol: "location.fill",
                    title: "Location",
                    subtitle: "Surface bounties in your 15km sector and unlock geofenced proof-of-presence.",
                    actionTitle: isLocationDone ? "Requested" : "Enable",
                    done: isLocationDone
                ) {
                    appState.location.requestAuthorization()
                    locationRequested = true
                }
                PermissionRow(
                    symbol: "bell.badge.fill",
                    title: "Notifications",
                    subtitle: "Get vicinity alerts when a requested item appears within reach.",
                    actionTitle: isNotifDone ? "Requested" : "Enable",
                    done: isNotifDone
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
    @State private var showLogin = false
    @State private var showSignup = false

    var body: some View {
        VStack(spacing: 0) {
            // Skip button
            HStack {
                Spacer()
                Button("Skip") {
                    onFinish()
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(RFColor.primary)
                .padding(.top, RFSpacing.md)
                .padding(.trailing, RFSpacing.lg)
            }

            Spacer(minLength: RFSpacing.lg)

            // Icon & Titles
            VStack(spacing: RFSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: RFRadius.md, style: .continuous)
                        .fill(RFColor.primary.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "touchid")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(RFColor.primary)
                }
                
                VStack(spacing: 4) {
                    Text("Rare Finder")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(RFColor.onSurface)
                    
                    Text("Your Journey\nBegins")
                        .font(.system(size: 44, weight: .black))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(RFColor.onSurface)
                        .lineSpacing(-4)
                }

                Text("Create an account to start tracking your\ntrust score and contributing to the network.")
                    .font(.rfBody(16))
                    .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, RFSpacing.xl)
            }

            Spacer()

            // Buttons
            VStack(spacing: RFSpacing.md) {
                // Apple Button
                Button(action: onFinish) {
                    HStack(spacing: 12) {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 20))
                        Text("Continue with Apple")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .foregroundStyle(.white)
                    .background(RFColor.onSurface, in: RoundedRectangle(cornerRadius: RFRadius.md, style: .continuous))
                }

                // Google Button
                Button(action: {}) {
                    HStack(spacing: 12) {
                        Image(systemName: "globe") // Placeholder
                            .font(.system(size: 18))
                            .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.6))
                        Text("Continue with Google")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .foregroundStyle(RFColor.onSurface)
                    .background(
                        RoundedRectangle(cornerRadius: RFRadius.md, style: .continuous)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: RFRadius.md, style: .continuous)
                            .stroke(RFColor.outlineVariant.opacity(0.3), lineWidth: 1)
                    )
                }

                // OR separator
                HStack(spacing: 16) {
                    Rectangle()
                        .fill(RFColor.outlineVariant.opacity(0.3))
                        .frame(height: 1)
                    Text("OR")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.4))
                    Rectangle()
                        .fill(RFColor.outlineVariant.opacity(0.3))
                        .frame(height: 1)
                }
                .padding(.vertical, RFSpacing.sm)

                // Email Button
                Button(action: { showSignup = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "envelope.fill")
                        Text("Sign up with Email")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .foregroundStyle(.white)
                    .background(RFColor.primaryGradient, in: RoundedRectangle(cornerRadius: RFRadius.md, style: .continuous))
                }
            }
            .padding(.horizontal, RFSpacing.lg)

            Spacer(minLength: RFSpacing.xl)

            // Footer
            HStack(spacing: 4) {
                Text("Already have an account?")
                    .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.8))
                Button("Log In") {
                    showLogin = true
                }
                .foregroundStyle(RFColor.primary)
                .fontWeight(.bold)
            }
            .font(.rfBody(15))
            .padding(.bottom, RFSpacing.xl)
        }
        .sheet(isPresented: $showLogin) {
            NavigationStack {
                AuthView(mode: .login) {
                    showLogin = false
                    onFinish()
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { showLogin = false }
                    }
                }
            }
        }
        .sheet(isPresented: $showSignup) {
            NavigationStack {
                AuthView(mode: .signup) {
                    showSignup = false
                    onFinish()
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { showSignup = false }
                    }
                }
            }
        }
    }
}



#Preview {
    OnboardingFlow()
        .environment(AppState())
}
