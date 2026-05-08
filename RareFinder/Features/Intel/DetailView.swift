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
        GeometryReader { geo in
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(spacing: 0) {
                        hero(geo: geo)
                        content
                    }
                }
                .background(RFColor.surface)
                .ignoresSafeArea(edges: .top)

                navBar(geo: geo)
            }
        }
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showReportSheet) {
            ReportFormView(prefilledBounty: bounty)
        }
        .onAppear {
            isClaimed = UserDefaults.standard.bool(forKey: verifyKey)
        }
    }

    private func navBar(geo: GeometryProxy) -> some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, RFSpacing.md)
        .padding(.top, max(geo.safeAreaInsets.top, 12)) 
    }

    private var shareText: String {
        "Rare Finder bounty — \(bounty.title) (\(bounty.district)). \(bounty.summary)"
    }

    private func launchScanner() {
        appState.location.requestAuthorization()
        appState.location.monitor(bounty: bounty)

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

    private func hero(geo: GeometryProxy) -> some View {
        let heroHeight = geo.size.width * 0.62 // Approx 16:10 for a wide hero
        
        return ZStack(alignment: .bottomLeading) {
            if let imageURL = bounty.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(RFColor.surfaceContainer)
                }
                .frame(width: geo.size.width, height: heroHeight)
                .clipped()
            } else {
                HeroIconArt(symbol: bounty.symbol, palette: [bounty.status.tint, RFColor.onSurface], iconSize: 180)
                    .frame(width: geo.size.width, height: heroHeight)
                    .clipped()
            }

            // Gradient overlay for text legibility
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: heroHeight * 0.5)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Tag(text: "LIVE INTEL", tint: RFColor.secondary)
                    Tag(text: bounty.category.rawValue, tint: .white.opacity(0.3))
                }
                Text(bounty.title)
                    .font(.rfTitle(30))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)

                Label(bounty.district.uppercased(), systemImage: "mappin.and.ellipse")
                    .font(.system(size: 10, weight: .black))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(RFSpacing.lg)
            .padding(.bottom, 60) // Extra padding for content card overlap
        }
        .frame(height: heroHeight)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: RFSpacing.lg) {
            // Overlapping Pill Header
            HStack {
                HStack(spacing: RFSpacing.sm) {
                    IconBadge(symbol: bounty.symbol, tint: RFColor.primary, size: 42)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("INTEL SCORE")
                            .font(.system(size: 8, weight: .black))
                            .tracking(1.2)
                            .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.5))
                        Text("#\(bounty.intelScore)")
                            .font(.system(size: 20, weight: .black))
                            .foregroundStyle(RFColor.onSurface)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("STATUS")
                        .font(.system(size: 8, weight: .black))
                        .tracking(1.2)
                        .foregroundStyle(bounty.status.tint)
                    Text(bounty.status.rawValue.uppercased())
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(RFColor.onSurface)
                }
            }
            .padding(RFSpacing.md)
            .background(RFColor.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 12, y: 4)

            VStack(alignment: .leading, spacing: RFSpacing.sm) {
                Eyebrow(text: "Intelligence Digest")
                Text(bounty.detail)
                    .font(.rfBody(15))
                    .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.8))
                    .lineSpacing(4)
            }
            .padding(.top, 8)

            geofenceCallout

            observationsList

            actionsSection
        }
        .padding(.horizontal, RFSpacing.md)
        .padding(.top, 24)
        .padding(.bottom, 40)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 32, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 32)
                .fill(RFColor.surface)
        )
        .padding(.top, -30) // Subtle overlap
    }

    private var actionsSection: some View {
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
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("DISPATCH")
                            .font(.system(size: 10, weight: .black))
                            .tracking(2)
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
            }
        }
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
        Task { await verifyBountyAsync() }
    }

    @MainActor
    private func verifyBountyAsync() async {
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

        let request = BackendClient.SubmitReportRequest(
            bounty_id: bounty.id,
            bounty_title: nil,
            hunter_name: profile?.displayName ?? "Guest Hunter",
            hunter_seed: profile?.avatarSeed,
            note: "Geofence verified — proof of presence within 50 m.",
            status: bounty.status.rawValue,
            district: bounty.district,
            latitude: bounty.latitude,
            longitude: bounty.longitude,
            symbol: "checkmark.shield.fill",
            is_geofence_verified: true,
            image_url: nil
        )

        do {
            let response = try await appState.sync.client.submitReport(request)
            await appState.sync.syncAll(context: context)
            UserDefaults.standard.set(true, forKey: verifyKey)
            isClaimed = true
            showToast("Verified — +\(response.points_awarded) Trust Points awarded.")
        } catch {
            showToast("Backend offline — try again when reconnected.")
        }
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

    private var observationsList: some View {
        VStack(alignment: .leading, spacing: RFSpacing.lg) {
            Eyebrow(text: "Field Intel (\(bounty.reports.count))")
                .padding(.top, 8)

            if bounty.reports.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 20))
                        .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.3))
                    Text("No field observations yet. Be the first to report intel.")
                        .font(.rfBody(14))
                        .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.5))
                }
                .padding(.vertical, 12)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(bounty.reports.sorted(by: { $0.createdAt > $1.createdAt })) { report in
                        CommentView(report: report)
                        if report.id != bounty.reports.sorted(by: { $0.createdAt > $1.createdAt }).last?.id {
                            Divider()
                                .padding(.vertical, 12)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct CommentView: View {
    let report: IntelReport
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Query private var profiles: [HunterProfile]
    @State private var replyText = ""
    @State private var showReplyField = false
    @State private var isSubmitting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                AvatarView(seed: report.hunterSeed, size: 36)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(report.hunterName)
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(RFColor.onSurface)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text("• \(report.createdAt.rf_relative)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.4))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    Text(report.note)
                        .font(.rfBody(15))
                        .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.9))
                        .lineSpacing(2)

                    if let imageURL = report.imageURL, let url = URL(string: imageURL) {
                        AsyncImage(url: url) { image in
                            image.resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(RFColor.surfaceContainer)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 150, maxHeight: 280)
                        .background(RFColor.surfaceContainer)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.top, 4)
                    } else {
                        // Fallback for reports without images
                        HeroIconArt(symbol: report.symbol, palette: [RFColor.primary], iconSize: 24)
                            .frame(maxWidth: .infinity)
                            .aspectRatio(2.4, contentMode: .fill)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                Text("No photo attached to this intel")
                                    .font(.rfBody(10))
                                    .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.4))
                                    .padding(8),
                                alignment: .bottomTrailing
                            )
                            .padding(.top, 4)
                    }
                }
            }

            HStack(spacing: 16) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showReplyField.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrowshape.turn.up.left.fill")
                            .font(.system(size: 10, weight: .black))
                        Text("REPLY")
                            .font(.system(size: 10, weight: .black))
                            .tracking(1.5)
                    }
                    .foregroundStyle(RFColor.primary)
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 48)

            if showReplyField {
                replyField
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.leading, 48)
            }

            if !report.replies.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(report.replies.sorted(by: { $0.createdAt < $1.createdAt })) { reply in
                        ReplyView(reply: reply, report: report)
                    }
                }
                .padding(.leading, 48)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var replyField: some View {
        HStack(spacing: 8) {
            TextField("Add intel reply...", text: $replyText)
                .font(.rfBody(14))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(RFColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(RFColor.outlineVariant.opacity(0.5), lineWidth: 1)
                )

            if isSubmitting {
                ProgressView()
                    .frame(width: 40, height: 40)
            } else {
                Button {
                    submitReply()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(replyText.isEmpty ? RFColor.onSurfaceVariant.opacity(0.1) : RFColor.primary)
                        )
                }
                .disabled(replyText.isEmpty)
                .buttonStyle(.plain)
            }
        }
    }

    private func submitReply() {
        guard !replyText.isEmpty else { return }
        isSubmitting = true

        let profile = profiles.first
        let request = BackendClient.SubmitReplyRequest(
            hunter_name: profile?.displayName ?? "Guest Hunter",
            hunter_seed: profile?.avatarSeed,
            content: replyText,
            parent_reply_id: nil
        )

        Task {
            do {
                let dto = try await appState.sync.client.submitReply(reportID: report.id, body: request)
                let newReply = IntelReply(
                    id: dto.id,
                    hunterName: dto.hunter_name,
                    hunterSeed: dto.hunter_seed,
                    content: dto.content,
                    createdAt: dto.created_at,
                    isRemote: true,
                    report: report,
                    parentReplyID: nil
                )
                context.insert(newReply)
                try context.save()

                await MainActor.run {
                    withAnimation {
                        replyText = ""
                        showReplyField = false
                        isSubmitting = false
                    }
                }
            } catch {
                await MainActor.run { isSubmitting = false }
            }
        }
    }
}

struct ReplyView: View {
    let reply: IntelReply
    let report: IntelReport
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Query private var profiles: [HunterProfile]
    @State private var replyText = ""
    @State private var showReplyField = false
    @State private var isSubmitting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                AvatarView(seed: reply.hunterSeed, size: 28)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(reply.hunterName)
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(RFColor.onSurface)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text("• \(reply.createdAt.rf_relative)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.4))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    Text(reply.content)
                        .font(.rfBody(14))
                        .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.85))
                }
            }

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showReplyField.toggle()
                }
            } label: {
                Text("REPLY")
                    .font(.system(size: 9, weight: .black))
                    .tracking(1.2)
                    .foregroundStyle(RFColor.primary)
            }
            .buttonStyle(.plain)
            .padding(.leading, 38)

            if showReplyField {
                HStack(spacing: 8) {
                    TextField("Reply to \(reply.hunterName)...", text: $replyText)
                        .font(.rfBody(13))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(RFColor.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(RFColor.outlineVariant.opacity(0.5), lineWidth: 1)
                        )

                    if isSubmitting {
                        ProgressView()
                            .frame(width: 32, height: 32)
                    } else {
                        Button {
                            submitReply()
                        } label: {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(replyText.isEmpty ? RFColor.onSurfaceVariant.opacity(0.1) : RFColor.primary)
                                )
                        }
                        .disabled(replyText.isEmpty)
                        .buttonStyle(.plain)
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.leading, 38)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func submitReply() {
        guard !replyText.isEmpty else { return }
        isSubmitting = true

        let profile = profiles.first
        let request = BackendClient.SubmitReplyRequest(
            hunter_name: profile?.displayName ?? "Guest Hunter",
            hunter_seed: profile?.avatarSeed,
            content: replyText,
            parent_reply_id: reply.id
        )

        Task {
            do {
                let dto = try await appState.sync.client.submitReply(reportID: report.id, body: request)
                let newReply = IntelReply(
                    id: dto.id,
                    hunterName: dto.hunter_name,
                    hunterSeed: dto.hunter_seed,
                    content: dto.content,
                    createdAt: dto.created_at,
                    isRemote: true,
                    report: report,
                    parentReplyID: reply.id
                )
                context.insert(newReply)
                try context.save()

                await MainActor.run {
                    withAnimation {
                        replyText = ""
                        showReplyField = false
                        isSubmitting = false
                    }
                }
            } catch {
                await MainActor.run { isSubmitting = false }
            }
        }
    }
}
