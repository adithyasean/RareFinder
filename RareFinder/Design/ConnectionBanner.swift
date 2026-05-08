import SwiftUI

/// Compact pill that surfaces the FastAPI backend's reachability state.
/// Tap to retry. Hidden once the connection is healthy and recent.
struct ConnectionBanner: View {
    let connection: SyncService.Connection
    let onRetry: () -> Void

    var body: some View {
        switch state {
        case .hidden:
            EmptyView()
        case .visible(let symbol, let title, let detail, let tint, let showsRetry):
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title.uppercased())
                        .font(.system(size: 10, weight: .black))
                        .tracking(1.4)
                        .foregroundStyle(tint)
                    Text(detail)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.75))
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                if showsRetry {
                    Button(action: onRetry) {
                        Text("Retry".uppercased())
                            .font(.system(size: 10, weight: .black))
                            .tracking(1.4)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .foregroundStyle(.white)
                            .background(Capsule().fill(tint))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Retry backend sync")
                }
            }
            .padding(.horizontal, RFSpacing.md)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(.background)
                    .overlay(Capsule().stroke(tint.opacity(0.4), lineWidth: 1))
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title). \(detail)")
        }
    }

    private enum BannerState {
        case hidden
        case visible(symbol: String, title: String, detail: String, tint: Color, showsRetry: Bool)
    }

    private var state: BannerState {
        switch connection {
        case .unknown:
            return .visible(
                symbol: "antenna.radiowaves.left.and.right.slash",
                title: "Linking grid",
                detail: "Reaching FastAPI backend…",
                tint: RFColor.outline,
                showsRetry: false
            )
        case .offline(let reason):
            return .visible(
                symbol: "wifi.exclamationmark",
                title: "Backend offline",
                detail: reason.isEmpty ? "Tap retry to reconnect." : reason,
                tint: RFColor.tertiary,
                showsRetry: true
            )
        case .online(let at):
            // Stay visible briefly so the user gets confirmation the
            // backend is live; otherwise hide to keep the UI clean.
            if Date.now.timeIntervalSince(at) < 4 {
                return .visible(
                    symbol: "checkmark.seal.fill",
                    title: "Backend live",
                    detail: "Synced \(at.rf_relative)",
                    tint: RFColor.secondary,
                    showsRetry: false
                )
            }
            return .hidden
        }
    }
}
