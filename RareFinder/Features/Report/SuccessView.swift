import SwiftUI

struct SuccessView: View {
    let pointsAwarded: Int
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            RFColor.surface.ignoresSafeArea()
            VStack(spacing: RFSpacing.lg) {
                Spacer()
                ZStack {
                    Circle()
                        .fill(RFColor.secondary.opacity(0.15))
                        .frame(width: 160, height: 160)
                        .blur(radius: 12)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 84, weight: .black))
                        .foregroundStyle(RFColor.secondary)
                        .accessibilityHidden(true)
                }

                VStack(spacing: RFSpacing.sm) {
                    Text("Intel Transmitted")
                        .font(.system(size: 34, weight: .black))
                        .foregroundStyle(RFColor.onSurface)
                        .minimumScaleFactor(0.8)
                    Text("Your verification has been logged on the grid. Rare Finder trust scores are updating.")
                        .font(.rfBody())
                        .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, RFSpacing.xl)
                }

                VStack(alignment: .leading, spacing: RFSpacing.sm) {
                    HStack {
                        Text("TRUST XP GAINED")
                            .font(.system(size: 10, weight: .black))
                            .tracking(1.5)
                            .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.5))
                        Spacer()
                        Text("+\(pointsAwarded) PTS")
                            .font(.system(size: 22, weight: .black))
                            .foregroundStyle(RFColor.primary)
                    }
                    ProgressView(value: min(1.0, Double(pointsAwarded) / 100.0))
                        .tint(RFColor.primary)
                }
                .padding(RFSpacing.lg)
                .rfElevatedCard(cornerRadius: 28)
                .padding(.horizontal, RFSpacing.xl)

                Spacer()

                RFDarkButton(title: "Return To Radar", icon: "arrow.left", action: onDismiss)
                    .padding(.horizontal, RFSpacing.lg)
                    .padding(.bottom, RFSpacing.xl)
            }
        }
        .accessibilityElement(children: .contain)
    }
}
