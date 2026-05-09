import SwiftUI

/// Container for the "Create" workflow. Shown as a modal sheet when the user
/// taps the "Create" tab. Splits the form into two segments per spec:
///   • **Intel** — exact location markers (current GPS or pinned). Can be
///     linked to an existing Bounty so the legacy "Add Intel from a bounty
///     detail" flow keeps working.
///   • **Bounty** — radius-based search areas (1–60 km diameter). Bounties
///     don't show on the global map; they only appear when picked from the
///     bounty feed.
struct CreateView: View {
    @Environment(\.dismiss) private var dismiss

    enum Mode: String, CaseIterable, Identifiable {
        case intel, bounty
        var id: String { rawValue }
        var label: String { self == .intel ? "Intel" : "Bounty" }
        var systemImage: String { self == .intel ? "mappin.and.ellipse" : "scope" }
    }

    /// Optional bounty pre-fill. When provided, the Intel segment opens with
    /// that bounty linked (used by DetailView's "Add Intel" button).
    let prefilledBounty: Bounty?
    /// Initial segment selection — defaults to Intel.
    @State private var mode: Mode

    init(prefilledBounty: Bounty? = nil, initialMode: Mode = .intel) {
        self.prefilledBounty = prefilledBounty
        self._mode = State(initialValue: initialMode)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases) { m in
                        Label(m.label, systemImage: m.systemImage).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("create_mode_picker")
                .padding(.horizontal, RFSpacing.md)
                .padding(.top, RFSpacing.sm)
                .padding(.bottom, RFSpacing.sm)

                Group {
                    switch mode {
                    case .intel:
                        ReportFormView(prefilledBounty: prefilledBounty, embedded: true)
                    case .bounty:
                        BountyFormView()
                    }
                }
                .id(mode) // ensure form state resets cleanly when toggling
            }
            .navigationTitle("Create")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

