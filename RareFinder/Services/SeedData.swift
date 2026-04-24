import Foundation
import SwiftData
import CoreLocation

/// Populates SwiftData on first launch with a rich demo corpus so the full
/// functionality of the app is discoverable immediately.
enum SeedData {
    static func bootstrapIfNeeded(context: ModelContext) {
        let bountyCount = (try? context.fetchCount(FetchDescriptor<Bounty>())) ?? 0
        guard bountyCount == 0 else { return }

        seedHunter(context)
        let bounties = seedBounties(context)
        seedReports(context, bounties: bounties)
        seedRewards(context)
        seedNotifications(context)
        seedModerationFlags(context)
        try? context.save()
    }

    private static func seedHunter(_ context: ModelContext) {
        let me = HunterProfile(
            displayName: "Alex Thorne",
            handle: "@alex.thorne",
            points: 1250,
            rank: 1240,
            verifications: 87,
            streak: 14,
            isModerator: true
        )
        context.insert(me)
    }

    private static func seedBounties(_ context: ModelContext) -> [Bounty] {
        let samples: [Bounty] = [
            Bounty(
                title: "Vintage Rolex Service",
                summary: "Verified by 8 experts",
                detail: "Heritage District workshop reports an open slot for Submariner servicing. Walk-ins accepted until 6pm.",
                category: .luxury,
                status: .available,
                coordinate: .init(latitude: 6.9271, longitude: 79.8612),
                district: "Heritage District",
                verifiedCount: 8,
                upvotes: 42,
                downvotes: 1,
                intelScore: 8224,
                symbol: "applewatch"
            ),
            Bounty(
                title: "The Rare Book Vault",
                summary: "Signed first editions available",
                detail: "Three signed first editions of Borges in rotation. Ask for Marta at the counter.",
                category: .books,
                status: .lowStock,
                coordinate: .init(latitude: 6.9150, longitude: 79.8500),
                district: "Westside",
                verifiedCount: 3,
                upvotes: 18,
                downvotes: 0,
                intelScore: 6100,
                symbol: "book.closed.fill"
            ),
            Bounty(
                title: "Premium Hardware Hub",
                summary: "91 Octane reported 10m ago",
                detail: "Shell on 4th Avenue received refueling truck this morning. Expect queues.",
                category: .fuelGrid,
                status: .available,
                coordinate: .init(latitude: 6.9280, longitude: 79.8650),
                district: "Downtown",
                verifiedCount: 12,
                upvotes: 34,
                downvotes: 2,
                intelScore: 7420,
                symbol: "fuelpump.fill"
            ),
            Bounty(
                title: "Antique Grandfather Clock",
                summary: "Circa 1920 • Sector 4.2",
                detail: "Pristine heritage timepiece. Recently serviced and fully functional. Restoration photos available on request.",
                category: .fineArt,
                status: .available,
                coordinate: .init(latitude: 6.9200, longitude: 79.8580),
                district: "Sector 4.2",
                verifiedCount: 6,
                upvotes: 27,
                downvotes: 0,
                intelScore: 9800,
                symbol: "clock.fill"
            ),
            Bounty(
                title: "MacBook Pro M3 Max Restock",
                summary: "3 units base config remaining",
                detail: "The Grove Apple Store confirmed silent restock at opening. Base config only.",
                category: .retroTech,
                status: .lowStock,
                coordinate: .init(latitude: 6.9310, longitude: 79.8700),
                district: "The Grove",
                verifiedCount: 4,
                upvotes: 22,
                downvotes: 1,
                intelScore: 5300,
                symbol: "laptopcomputer"
            ),
            Bounty(
                title: "Insulin Pens — Emergency Supply",
                summary: "Pharmacy confirmed arrival",
                detail: "City Pharmacy received restock overnight. Prescriptions required; limit 2 per household.",
                category: .medical,
                status: .available,
                coordinate: .init(latitude: 6.9100, longitude: 79.8700),
                district: "Eastside",
                verifiedCount: 9,
                upvotes: 61,
                downvotes: 0,
                intelScore: 11200,
                symbol: "cross.case.fill"
            ),
            Bounty(
                title: "Limited-Run Sneakers",
                summary: "Out of stock",
                detail: "Queue cleared by 9am. Next drop rumored for Friday. Monitoring continues.",
                category: .limitedGear,
                status: .outOfStock,
                coordinate: .init(latitude: 6.9350, longitude: 79.8550),
                district: "Northline",
                verifiedCount: 14,
                upvotes: 16,
                downvotes: 8,
                intelScore: 4100,
                symbol: "shippingbox.fill"
            ),
            Bounty(
                title: "Specialty Espresso Beans",
                summary: "Micro-lot arrival",
                detail: "Coffee bar released a 5kg micro-lot. Espresso-grade, cinnamon and stonefruit notes.",
                category: .services,
                status: .lowStock,
                coordinate: .init(latitude: 6.9220, longitude: 79.8630),
                district: "Old Town",
                verifiedCount: 2,
                upvotes: 9,
                downvotes: 0,
                intelScore: 3050,
                symbol: "cup.and.saucer.fill"
            )
        ]
        samples.forEach { context.insert($0) }
        return samples
    }

    private static func seedReports(_ context: ModelContext, bounties: [Bounty]) {
        let now = Date()
        let reports: [IntelReport] = [
            IntelReport(
                hunterName: "Marcus V.",
                note: "Just spotted 91 Octane at Shell on 4th. Lines are moving fast, looks like they just got a refill. Get it while it lasts.",
                status: .available,
                district: "Downtown",
                coordinate: bounties[2].coordinate,
                upvotes: 24, downvotes: 2,
                symbol: "fuelpump.fill",
                pointsAwarded: 75,
                createdAt: now.addingTimeInterval(-120),
                bounty: bounties[2]
            ),
            IntelReport(
                hunterName: "Elena Thorne",
                note: "Apple Store at The Grove has MacBook Pro M3 Max back in stock, but only 3 units left in the base configuration.",
                status: .lowStock,
                district: "Westside",
                coordinate: bounties[4].coordinate,
                upvotes: 12, downvotes: 0,
                symbol: "laptopcomputer",
                pointsAwarded: 60,
                createdAt: now.addingTimeInterval(-900),
                bounty: bounties[4]
            ),
            IntelReport(
                hunterName: "Priya S.",
                note: "Insulin pens confirmed. Pharmacist processing prescriptions now, no rush on the line.",
                status: .available,
                district: "Eastside",
                coordinate: bounties[5].coordinate,
                upvotes: 38, downvotes: 0,
                symbol: "cross.case.fill",
                pointsAwarded: 100,
                createdAt: now.addingTimeInterval(-1800),
                bounty: bounties[5]
            ),
            IntelReport(
                hunterName: "Kenji O.",
                note: "Queue just cleared at the sneaker drop. Staff confirmed no restock today.",
                status: .outOfStock,
                district: "Northline",
                coordinate: bounties[6].coordinate,
                upvotes: 8, downvotes: 2,
                symbol: "shippingbox.fill",
                pointsAwarded: 40,
                createdAt: now.addingTimeInterval(-2600),
                bounty: bounties[6]
            )
        ]
        reports.forEach { context.insert($0) }
    }

    private static func seedRewards(_ context: ModelContext) {
        let rewards: [Reward] = [
            Reward(
                title: "Priority Drop Intel",
                summary: "Secure early access to sector 9-B hardware drops.",
                detail: "Get 24-hour headstart notifications for high-value hardware bounties within your primary hunter grid.",
                cost: 400,
                symbol: "bolt.badge.clock.fill",
                isFeatured: true
            ),
            Reward(
                title: "Neural Buffer Unit",
                summary: "Boost grid scan recovery time by 25% for 48h.",
                detail: "Extend your daily report quota and reduce the cooldown between verifications.",
                cost: 750,
                symbol: "cpu.fill"
            ),
            Reward(
                title: "Ghost Protocol",
                summary: "Remain invisible to other hunters on the mini-map.",
                detail: "Cloaked pins, unlisted bounty participation, and anonymized leaderboard entry.",
                cost: 1200,
                symbol: "eye.slash.fill"
            ),
            Reward(
                title: "Bounty Boost",
                summary: "Pin your own request to the top of the local feed.",
                detail: "Jump to the top of the verification queue for one active request.",
                cost: 200,
                symbol: "arrow.up.circle.fill"
            )
        ]
        rewards.forEach { context.insert($0) }
    }

    private static func seedNotifications(_ context: ModelContext) {
        let now = Date()
        let items: [AppNotification] = [
            AppNotification(
                title: "Target in Vicinity",
                body: "Rare asset detected 0.2 mi from your current coordinates. Accuracy index 98%.",
                kind: .vicinity,
                createdAt: now.addingTimeInterval(-180),
                symbol: "scope"
            ),
            AppNotification(
                title: "Intel Verified",
                body: "Your Heritage Clock report was verified by 4 hunters. +50 XP.",
                kind: .verification,
                createdAt: now.addingTimeInterval(-1800),
                read: true,
                symbol: "checkmark.seal.fill"
            ),
            AppNotification(
                title: "Reward Unlocked",
                body: "You are 250 points away from Platinum Tier.",
                kind: .reward,
                createdAt: now.addingTimeInterval(-3600 * 4),
                read: true,
                symbol: "trophy.fill"
            ),
            AppNotification(
                title: "Grid Maintenance",
                body: "Scheduled grid refresh completes at 03:00 local.",
                kind: .system,
                createdAt: now.addingTimeInterval(-3600 * 20),
                read: true,
                symbol: "gearshape.2.fill"
            )
        ]
        items.forEach { context.insert($0) }
    }

    private static func seedModerationFlags(_ context: ModelContext) {
        let flags: [ModerationFlag] = [
            ModerationFlag(
                title: "Data Inconsistency",
                handle: "@ScoutMaster",
                reason: "Coordinate drift detected. Bounty tagged in oceanic exclusion zone.",
                sightingCount: 3
            ),
            ModerationFlag(
                title: "Behavioral Alert",
                handle: "@NatureLover22",
                reason: "High-frequency reporting pattern suggests non-human automation.",
                sightingCount: 1
            ),
            ModerationFlag(
                title: "Stale Intel",
                handle: "@GridWalker",
                reason: "Reports stock levels matching last week's cached data verbatim.",
                sightingCount: 2
            )
        ]
        flags.forEach { context.insert($0) }
    }
}
