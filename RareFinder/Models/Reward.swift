import Foundation
import SwiftData

@Model
final class Reward {
    @Attribute(.unique) var id: UUID
    var title: String
    var summary: String
    var detail: String
    var cost: Int
    var symbol: String
    var isFeatured: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        summary: String,
        detail: String,
        cost: Int,
        symbol: String,
        isFeatured: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.detail = detail
        self.cost = cost
        self.symbol = symbol
        self.isFeatured = isFeatured
        self.createdAt = createdAt
    }
}
