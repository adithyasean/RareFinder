import SwiftUI

struct Eyebrow: View {
    let text: String
    var color: Color = RFColor.onSurfaceVariant.opacity(0.6)
    var body: some View {
        Text(text.uppercased())
            .font(.rfEyebrow())
            .tracking(2)
            .foregroundStyle(color)
            .accessibilityAddTraits(.isHeader)
    }
}

struct SectionHeader: View {
    let title: String
    var eyebrow: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let eyebrow {
                Eyebrow(text: eyebrow, color: RFColor.primary)
            }
            Text(title)
                .font(.system(size: 30, weight: .black))
                .foregroundStyle(RFColor.onSurface)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

enum BountyStatus: String, Codable, CaseIterable, Identifiable {
    case available = "Available"
    case lowStock = "Low Stock"
    case outOfStock = "Out of Stock"
    case unverified = "Unverified"

    var id: String { rawValue }

    var tint: Color {
        switch self {
        case .available: return RFColor.secondary
        case .lowStock: return RFColor.primary
        case .outOfStock: return RFColor.tertiary
        case .unverified: return RFColor.outline
        }
    }

    var symbol: String {
        switch self {
        case .available: return "checkmark.circle.fill"
        case .lowStock: return "exclamationmark.triangle.fill"
        case .outOfStock: return "xmark.octagon.fill"
        case .unverified: return "questionmark.circle.fill"
        }
    }
}

struct StatusPill: View {
    let status: BountyStatus
    var compact: Bool = false
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.tint)
                .frame(width: 8, height: 8)
            Text(status.rawValue.uppercased())
                .font(.system(size: compact ? 9 : 10, weight: .black))
                .tracking(1.2)
                .foregroundStyle(status.tint)
        }
        .padding(.horizontal, compact ? 8 : 12)
        .padding(.vertical, compact ? 4 : 6)
        .background(
            Capsule().fill(status.tint.opacity(0.1))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status: \(status.rawValue)")
    }
}

struct RFPrimaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon { Image(systemName: icon) }
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .black))
                    .tracking(3)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(.white)
            .background(RFColor.primaryGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: RFColor.primary.opacity(0.3), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

struct RFSecondaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon { Image(systemName: icon) }
                Text(title.uppercased())
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
        .accessibilityLabel(title)
    }
}

struct RFDarkButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon { Image(systemName: icon) }
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .black))
                    .tracking(3)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(.white)
            .background(RFColor.onSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: RFColor.onSurface.opacity(0.25), radius: 18, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

struct IconBadge: View {
    let symbol: String
    var tint: Color = RFColor.primary
    var size: CGFloat = 44
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.45, weight: .bold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct AvatarView: View {
    let seed: String
    var size: CGFloat = 40
    private var palette: [Color] {
        [RFColor.primary, RFColor.secondary, RFColor.tertiary, RFColor.primaryDeep, RFColor.outline]
    }
    private var initials: String {
        let parts = seed.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }
    private var background: Color {
        let hash = seed.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[hash % palette.count]
    }
    var body: some View {
        Text(initials.isEmpty ? "?" : initials)
            .font(.system(size: size * 0.4, weight: .black))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(colors: [background.opacity(0.85), background], startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
            )
            .accessibilityLabel("Avatar for \(seed)")
    }
}

struct HeroIconArt: View {
    let symbol: String
    var palette: [Color] = [RFColor.primary, RFColor.primaryDeep]
    var body: some View {
        ZStack {
            LinearGradient(colors: palette.map { $0.opacity(0.15) }, startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: symbol)
                .font(.system(size: 64, weight: .black))
                .foregroundStyle(LinearGradient(colors: palette, startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .accessibilityHidden(true)
    }
}
