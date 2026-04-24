import Foundation
import SwiftData

enum NotificationKind: String, Codable, CaseIterable {
    case vicinity
    case verification
    case reward
    case system
}

@Model
final class AppNotification {
    @Attribute(.unique) var id: UUID
    var title: String
    var body: String
    var kindRaw: String
    var createdAt: Date
    var read: Bool
    var symbol: String

    init(
        id: UUID = UUID(),
        title: String,
        body: String,
        kind: NotificationKind = .vicinity,
        createdAt: Date = .now,
        read: Bool = false,
        symbol: String = "bell.fill"
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.kindRaw = kind.rawValue
        self.createdAt = createdAt
        self.read = read
        self.symbol = symbol
    }

    var kind: NotificationKind {
        get { NotificationKind(rawValue: kindRaw) ?? .system }
        set { kindRaw = newValue.rawValue }
    }
}
