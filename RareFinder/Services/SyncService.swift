import Foundation
import Observation
import SwiftData
import CoreLocation

@MainActor
@Observable
final class SyncService {
    enum Status: Equatable {
        case idle, syncing, synced(Date), offline(String)
    }

    private let client: BackendClient
    private(set) var status: Status = .idle

    init(client: BackendClient? = nil) {
        self.client = client ?? BackendClient()
    }

    /// Attempts to pull the full backend corpus and merge it into SwiftData.
    /// Missing records are inserted, known records are updated. Failures are
    /// treated as non-fatal — callers continue with whatever is cached locally.
    func syncAll(context: ModelContext) async {
        status = .syncing
        do {
            async let bounties = client.fetchBounties()
            async let reports = client.fetchReports()
            async let hunter = client.fetchHunter()
            async let rewards = client.fetchRewards()
            async let notifs = client.fetchNotifications()
            async let flags = client.fetchFlags()

            let (b, r, h, rw, n, f) = try await (bounties, reports, hunter, rewards, notifs, flags)
            try mergeBounties(b, context: context)
            try mergeReports(r, context: context)
            try mergeHunter(h, context: context)
            try mergeRewards(rw, context: context)
            try mergeNotifications(n, context: context)
            try mergeFlags(f, context: context)
            try context.save()
            status = .synced(.now)
        } catch {
            status = .offline(error.localizedDescription)
        }
    }

    // MARK: - Merge helpers

    private func mergeBounties(_ dtos: [BackendClient.BountyDTO], context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<Bounty>())
        let index = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        let incomingIDs = Set(dtos.map(\.id))
        for dto in dtos {
            if let local = index[dto.id] {
                local.title = dto.title
                local.summary = dto.summary
                local.detail = dto.detail
                local.categoryRaw = dto.category
                local.statusRaw = dto.status
                local.latitude = dto.latitude
                local.longitude = dto.longitude
                local.district = dto.district
                local.verifiedCount = dto.verified_count
                local.upvotes = dto.upvotes
                local.downvotes = dto.downvotes
                local.intelScore = dto.intel_score
                local.symbol = dto.symbol
                local.updatedAt = dto.updated_at
                local.isRemote = true
            } else {
                context.insert(Bounty(
                    id: dto.id,
                    title: dto.title,
                    summary: dto.summary,
                    detail: dto.detail,
                    category: BountyCategory(rawValue: dto.category) ?? .services,
                    status: BountyStatus(rawValue: dto.status) ?? .unverified,
                    coordinate: CLLocationCoordinate2D(latitude: dto.latitude, longitude: dto.longitude),
                    district: dto.district,
                    verifiedCount: dto.verified_count,
                    upvotes: dto.upvotes,
                    downvotes: dto.downvotes,
                    intelScore: dto.intel_score,
                    symbol: dto.symbol,
                    isRemote: true,
                    createdAt: dto.created_at,
                    updatedAt: dto.updated_at
                ))
            }
        }
        for stale in existing where stale.isRemote && !incomingIDs.contains(stale.id) {
            context.delete(stale)
        }
    }

    private func mergeReports(_ dtos: [BackendClient.IntelReportDTO], context: ModelContext) throws {
        let existingReports = try context.fetch(FetchDescriptor<IntelReport>())
        let reportIndex = Dictionary(uniqueKeysWithValues: existingReports.map { ($0.id, $0) })
        let bountyIndex = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<Bounty>()).map { ($0.id, $0) })
        let incomingIDs = Set(dtos.map(\.id))
        for dto in dtos {
            let bounty = dto.bounty_id.flatMap { bountyIndex[$0] }
            if let local = reportIndex[dto.id] {
                local.hunterName = dto.hunter_name
                local.hunterSeed = dto.hunter_seed
                local.note = dto.note
                local.statusRaw = dto.status
                local.district = dto.district
                local.latitude = dto.latitude
                local.longitude = dto.longitude
                local.upvotes = dto.upvotes
                local.downvotes = dto.downvotes
                local.symbol = dto.symbol
                local.pointsAwarded = dto.points_awarded
                local.bounty = bounty
                local.isRemote = true
            } else {
                context.insert(IntelReport(
                    id: dto.id,
                    hunterName: dto.hunter_name,
                    hunterSeed: dto.hunter_seed,
                    note: dto.note,
                    status: BountyStatus(rawValue: dto.status) ?? .unverified,
                    district: dto.district,
                    coordinate: CLLocationCoordinate2D(latitude: dto.latitude, longitude: dto.longitude),
                    upvotes: dto.upvotes,
                    downvotes: dto.downvotes,
                    symbol: dto.symbol,
                    pointsAwarded: dto.points_awarded,
                    isRemote: true,
                    createdAt: dto.created_at,
                    bounty: bounty
                ))
            }
        }
        for stale in existingReports where stale.isRemote && !incomingIDs.contains(stale.id) {
            context.delete(stale)
        }
    }

    private func mergeHunter(_ dto: BackendClient.HunterDTO, context: ModelContext) throws {
        let profiles = try context.fetch(FetchDescriptor<HunterProfile>())
        if let profile = profiles.first {
            profile.displayName = dto.display_name
            profile.handle = dto.handle
            profile.avatarSeed = dto.avatar_seed
            profile.points = dto.points
            profile.rank = dto.rank
            profile.verifications = dto.verifications
            profile.streak = dto.streak
            profile.isModerator = dto.is_moderator
        } else {
            context.insert(HunterProfile(
                id: dto.id,
                displayName: dto.display_name,
                handle: dto.handle,
                avatarSeed: dto.avatar_seed,
                points: dto.points,
                rank: dto.rank,
                verifications: dto.verifications,
                streak: dto.streak,
                isModerator: dto.is_moderator
            ))
        }
    }

    private func mergeRewards(_ dtos: [BackendClient.RewardDTO], context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<Reward>())
        let index = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        let incomingIDs = Set(dtos.map(\.id))
        for dto in dtos {
            if let local = index[dto.id] {
                local.title = dto.title
                local.summary = dto.summary
                local.detail = dto.detail
                local.cost = dto.cost
                local.symbol = dto.symbol
                local.isFeatured = dto.is_featured
                local.isRemote = true
            } else {
                context.insert(Reward(
                    id: dto.id,
                    title: dto.title,
                    summary: dto.summary,
                    detail: dto.detail,
                    cost: dto.cost,
                    symbol: dto.symbol,
                    isFeatured: dto.is_featured,
                    isRemote: true
                ))
            }
        }
        for stale in existing where stale.isRemote && !incomingIDs.contains(stale.id) {
            context.delete(stale)
        }
    }

    private func mergeNotifications(_ dtos: [BackendClient.NotificationDTO], context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<AppNotification>())
        let index = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        let incomingIDs = Set(dtos.map(\.id))
        for dto in dtos {
            if let local = index[dto.id] {
                local.title = dto.title
                local.body = dto.body
                local.kindRaw = dto.kind
                local.symbol = dto.symbol
                local.read = dto.read
                local.isRemote = true
            } else {
                context.insert(AppNotification(
                    id: dto.id,
                    title: dto.title,
                    body: dto.body,
                    kind: NotificationKind(rawValue: dto.kind) ?? .system,
                    createdAt: dto.created_at,
                    read: dto.read,
                    symbol: dto.symbol,
                    isRemote: true
                ))
            }
        }
        for stale in existing where stale.isRemote && !incomingIDs.contains(stale.id) {
            context.delete(stale)
        }
    }

    private func mergeFlags(_ dtos: [BackendClient.ModerationFlagDTO], context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<ModerationFlag>())
        let index = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        let incomingIDs = Set(dtos.map(\.id))
        for dto in dtos {
            if let local = index[dto.id] {
                local.title = dto.title
                local.handle = dto.handle
                local.reason = dto.reason
                local.sightingCount = dto.sighting_count
                local.statusRaw = dto.status
                local.isRemote = true
            } else {
                context.insert(ModerationFlag(
                    id: dto.id,
                    title: dto.title,
                    handle: dto.handle,
                    reason: dto.reason,
                    sightingCount: dto.sighting_count,
                    status: FlagStatus(rawValue: dto.status) ?? .pending,
                    createdAt: dto.created_at,
                    isRemote: true
                ))
            }
        }
        for stale in existing where stale.isRemote && !incomingIDs.contains(stale.id) {
            context.delete(stale)
        }
    }
}
