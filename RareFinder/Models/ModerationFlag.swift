import Foundation
import SwiftData

enum FlagStatus: String, Codable {
    case pending, quarantined, actioned
}

@Model
final class ModerationFlag {
    @Attribute(.unique) var id: UUID
    var title: String
    var handle: String
    var reason: String
    var sightingCount: Int
    var statusRaw: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        handle: String,
        reason: String,
        sightingCount: Int = 1,
        status: FlagStatus = .pending,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.handle = handle
        self.reason = reason
        self.sightingCount = sightingCount
        self.statusRaw = status.rawValue
        self.createdAt = createdAt
    }

    var status: FlagStatus {
        get { FlagStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }
}
