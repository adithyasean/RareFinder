import Foundation
import SwiftData

enum HunterTier: String, Codable, CaseIterable {
    case bronze, silver, gold, platinum, elite

    var title: String { rawValue.capitalized + " Hunter" }

    var accent: String {
        switch self {
        case .bronze: return "medal.fill"
        case .silver: return "medal.fill"
        case .gold: return "trophy.fill"
        case .platinum: return "crown.fill"
        case .elite: return "star.circle.fill"
        }
    }

    static func forPoints(_ points: Int) -> HunterTier {
        switch points {
        case ..<250: return .bronze
        case 250..<750: return .silver
        case 750..<2000: return .gold
        case 2000..<5000: return .platinum
        default: return .elite
        }
    }
}

@Model
final class HunterProfile {
    @Attribute(.unique) var id: UUID
    var displayName: String
    var handle: String
    var avatarSeed: String
    var points: Int
    var rank: Int
    var verifications: Int
    var streak: Int
    var isModerator: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        displayName: String,
        handle: String,
        avatarSeed: String? = nil,
        points: Int = 0,
        rank: Int = 0,
        verifications: Int = 0,
        streak: Int = 0,
        isModerator: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.displayName = displayName
        self.handle = handle
        self.avatarSeed = avatarSeed ?? displayName
        self.points = points
        self.rank = rank
        self.verifications = verifications
        self.streak = streak
        self.isModerator = isModerator
        self.createdAt = createdAt
    }

    var tier: HunterTier { HunterTier.forPoints(points) }
}
