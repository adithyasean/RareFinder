import SwiftUI

enum RFColor {
    static let primary = Color(red: 1.0, green: 0.584, blue: 0.0)            // #FF9500
    static let primaryDeep = Color(red: 0.549, green: 0.314, blue: 0.0)      // #8c5000
    static let secondary = Color(red: 0.0, green: 0.431, blue: 0.157)        // #006e28
    static let secondaryContainer = Color(red: 0.435, green: 0.984, blue: 0.522) // #6ffb85
    static let tertiary = Color(red: 0.753, green: 0.0, blue: 0.039)         // #c0000a
    static let tertiaryContainer = Color(red: 1.0, green: 0.565, blue: 0.510) // #ff9082
    static let surface = Color(red: 0.980, green: 0.976, blue: 0.996)        // #faf9fe
    static let surfaceContainerLow = Color(red: 0.957, green: 0.953, blue: 0.973) // #f4f3f8
    static let surfaceContainer = Color(red: 0.933, green: 0.929, blue: 0.953) // #eeedf3
    static let onSurface = Color(red: 0.102, green: 0.106, blue: 0.122)      // #1a1b1f
    static let onSurfaceVariant = Color(red: 0.333, green: 0.263, blue: 0.204) // #554334
    static let outline = Color(red: 0.533, green: 0.451, blue: 0.380)        // #887361
    static let outlineVariant = Color(red: 0.859, green: 0.761, blue: 0.678) // #dbc2ad

    static var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 1.0, green: 0.682, blue: 0.0), primary],
            startPoint: .top, endPoint: .bottom
        )
    }
}

enum RFSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

enum RFRadius {
    static let sm: CGFloat = 12
    static let md: CGFloat = 20
    static let lg: CGFloat = 32
    static let xl: CGFloat = 40
}

extension View {
    func rfCardStyle(cornerRadius: CGFloat = RFRadius.md) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(RFColor.outlineVariant.opacity(0.25), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    func rfElevatedCard(cornerRadius: CGFloat = RFRadius.lg) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(RFColor.outlineVariant.opacity(0.2), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.12), radius: 24, y: 12)
    }
}

extension Font {
    static func rfTitle(_ size: CGFloat = 34) -> Font {
        .system(size: size, weight: .black, design: .default).width(.compressed)
    }
    static func rfEyebrow(_ size: CGFloat = 10) -> Font {
        .system(size: size, weight: .black, design: .default)
    }
    static func rfBody(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .medium, design: .default)
    }
}
