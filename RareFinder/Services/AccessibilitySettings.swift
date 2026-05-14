import Foundation
import Observation
import SwiftUI

/// App-level accessibility toggles that act as quick-trigger overrides on
/// top of the system Accessibility settings. These are persisted in
/// UserDefaults and surfaced from `SettingsView`.
@Observable
@MainActor
final class AccessibilitySettings {
    enum TextScale: String, CaseIterable, Identifiable {
        case standard, large, extraLarge

        var id: String { rawValue }
        var label: String {
            switch self {
            case .standard: return "Standard"
            case .large: return "Large"
            case .extraLarge: return "Extra Large"
            }
        }
        var multiplier: CGFloat {
            switch self {
            case .standard: return 1.0
            case .large: return 1.15
            case .extraLarge: return 1.35
            }
        }
        var dynamicTypeSize: DynamicTypeSize {
            switch self {
            case .standard: return .large
            case .large: return .xLarge
            case .extraLarge: return .accessibility2
            }
        }
    }

    private let defaults = UserDefaults.standard

    var boldText: Bool { didSet { defaults.set(boldText, forKey: Keys.bold) } }
    var highContrast: Bool { didSet { defaults.set(highContrast, forKey: Keys.contrast) } }
    var reduceMotion: Bool { didSet { defaults.set(reduceMotion, forKey: Keys.motion) } }
    var voiceHints: Bool { didSet { defaults.set(voiceHints, forKey: Keys.voiceHints) } }
    var hapticFeedback: Bool { didSet { defaults.set(hapticFeedback, forKey: Keys.haptics) } }
    var textScale: TextScale {
        didSet { defaults.set(textScale.rawValue, forKey: Keys.textScale) }
    }

    init() {
        self.boldText = defaults.bool(forKey: Keys.bold)
        self.highContrast = defaults.bool(forKey: Keys.contrast)
        // Default reduceMotion / haptics to user-friendly values when first launched.
        if defaults.object(forKey: Keys.motion) == nil { defaults.set(false, forKey: Keys.motion) }
        self.reduceMotion = defaults.bool(forKey: Keys.motion)
        if defaults.object(forKey: Keys.haptics) == nil { defaults.set(true, forKey: Keys.haptics) }
        self.hapticFeedback = defaults.bool(forKey: Keys.haptics)
        self.voiceHints = defaults.bool(forKey: Keys.voiceHints)
        let raw = defaults.string(forKey: Keys.textScale) ?? TextScale.standard.rawValue
        self.textScale = TextScale(rawValue: raw) ?? .standard
    }

    /// Quick-trigger reset that disables every accessibility override.
    func resetAll() {
        boldText = false
        highContrast = false
        reduceMotion = false
        voiceHints = false
        hapticFeedback = true
        textScale = .standard
    }

    /// Quick-trigger preset that enables every accessibility override at
    /// once — useful for testing the full surface in a single tap.
    func enableAll() {
        boldText = true
        highContrast = true
        reduceMotion = true
        voiceHints = true
        hapticFeedback = true
        textScale = .extraLarge
    }

    private enum Keys {
        static let bold = "rf.a11y.boldText"
        static let contrast = "rf.a11y.highContrast"
        static let motion = "rf.a11y.reduceMotion"
        static let voiceHints = "rf.a11y.voiceHints"
        static let haptics = "rf.a11y.haptics"
        static let textScale = "rf.a11y.textScale"
    }
}

/// SwiftUI modifier that applies the active accessibility overrides to
/// the entire view hierarchy. Apply once near the root.
///
/// Avoids AnyView to preserve SwiftUI structural identity — toggling a
/// setting won't destroy the view tree (which would reset navigation).
struct AccessibilityOverridesModifier: ViewModifier {
    @Environment(AppState.self) private var appState

    func body(content: Content) -> some View {
        let a11y = appState.accessibility
        content
            .dynamicTypeSize(a11y.textScale.dynamicTypeSize)
            .environment(\.legibilityWeight, a11y.boldText ? .bold : .regular)
            .contrast(a11y.highContrast ? 1.15 : 1.0)
            .transaction { tx in
                if a11y.reduceMotion { tx.disablesAnimations = true }
            }
    }
}

extension View {
    func rfAccessibilityOverrides() -> some View {
        modifier(AccessibilityOverridesModifier())
    }
}
