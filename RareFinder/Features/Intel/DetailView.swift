import SwiftUI
import CoreLocation

struct DetailView: View {
    let bounty: Bounty
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

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
                    appState.location.monitor(bounty: bounty)
                }
                HStack(spacing: RFSpacing.sm) {
                    RFSecondaryButton(title: "Add Intel", icon: "plus.circle.fill") { }
                    RFSecondaryButton(title: "Dispatch", icon: "square.and.arrow.up") { }
                }
            }
        }
        .padding(RFSpacing.lg)
        .rfElevatedCard(cornerRadius: 36)
        .padding(.top, 16)
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
