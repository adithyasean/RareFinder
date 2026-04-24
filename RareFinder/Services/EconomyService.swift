import Foundation

/// Gamified micro-economy rules. Pure, side-effect free — suitable for unit tests.
struct EconomyService {
    enum ReportQuality {
        case firstSighting, verification, challenge, duplicate
    }

    static let basePoints = 50
    static let verificationBonus = 25
    static let firstSightingBonus = 100
    static let duplicatePenalty = -20
    static let challengeReward = 10
    static let bountyBoostCost = 150
    static let minimumBalance = 0

    /// Points awarded for a submitted intel report.
    static func pointsForReport(quality: ReportQuality, isGeofenceVerified: Bool) -> Int {
        guard isGeofenceVerified else { return 0 }
        switch quality {
        case .firstSighting: return basePoints + firstSightingBonus
        case .verification:  return basePoints + verificationBonus
        case .challenge:     return challengeReward
        case .duplicate:     return max(duplicatePenalty, -basePoints)
        }
    }

    /// Returns new balance after redeeming a reward, or nil if unaffordable.
    static func redeem(balance: Int, cost: Int) -> Int? {
        guard cost >= 0 else { return nil }
        let remaining = balance - cost
        return remaining >= minimumBalance ? remaining : nil
    }

    /// Cost to boost a bounty to the top of the feed.
    static func boostCost(currentPriority: Int) -> Int {
        bountyBoostCost + max(0, currentPriority) * 25
    }

    /// Level thresholds: returns progress in [0, 1] toward the next tier.
    static func tierProgress(points: Int) -> Double {
        let tier = HunterTier.forPoints(points)
        let (lo, hi): (Int, Int) = {
            switch tier {
            case .bronze:   return (0, 250)
            case .silver:   return (250, 750)
            case .gold:     return (750, 2000)
            case .platinum: return (2000, 5000)
            case .elite:    return (5000, 10000)
            }
        }()
        guard hi > lo else { return 1 }
        let clamped = max(lo, min(points, hi))
        return Double(clamped - lo) / Double(hi - lo)
    }
}
