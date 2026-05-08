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
    var category: String = "other"
    var bountyID: UUID? = nil
    var reportID: UUID? = nil
    var createdAt: Date
    var isRemote: Bool = false

    init(
        id: UUID = UUID(),
        title: String,
        handle: String,
        reason: String,
        sightingCount: Int = 1,
        status: FlagStatus = .pending,
        category: String = "other",
        bountyID: UUID? = nil,
        reportID: UUID? = nil,
        createdAt: Date = .now,
        isRemote: Bool = false
    ) {
        self.id = id
        self.title = title
        self.handle = handle
        self.reason = reason
        self.sightingCount = sightingCount
        self.statusRaw = status.rawValue
        self.category = category
        self.bountyID = bountyID
        self.reportID = reportID
        self.createdAt = createdAt
        self.isRemote = isRemote
    }

    var status: FlagStatus {
        get { FlagStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }
}
