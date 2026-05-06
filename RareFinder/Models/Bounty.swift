import Foundation
import SwiftData
import CoreLocation

@Model
final class Bounty {
    @Attribute(.unique) var id: UUID
    var title: String
    var summary: String
    var detail: String
    var categoryRaw: String
    var statusRaw: String
    var latitude: Double
    var longitude: Double
    var district: String
    var verifiedCount: Int
    var upvotes: Int
    var downvotes: Int
    var intelScore: Int
    var createdAt: Date
    var updatedAt: Date
    var symbol: String
    var isRemote: Bool = false
    @Relationship(deleteRule: .cascade, inverse: \IntelReport.bounty) var reports: [IntelReport] = []

    init(
        id: UUID = UUID(),
        title: String,
        summary: String,
        detail: String,
        category: BountyCategory,
        status: BountyStatus,
        coordinate: CLLocationCoordinate2D,
        district: String,
        verifiedCount: Int = 0,
        upvotes: Int = 0,
        downvotes: Int = 0,
        intelScore: Int = 1000,
        symbol: String? = nil,
        isRemote: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.detail = detail
        self.categoryRaw = category.rawValue
        self.statusRaw = status.rawValue
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.district = district
        self.verifiedCount = verifiedCount
        self.upvotes = upvotes
        self.downvotes = downvotes
        self.intelScore = intelScore
        self.symbol = symbol ?? category.symbol
        self.isRemote = isRemote
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var category: BountyCategory {
        get { BountyCategory(rawValue: categoryRaw) ?? .services }
        set { categoryRaw = newValue.rawValue }
    }

    var status: BountyStatus {
        get { BountyStatus(rawValue: statusRaw) ?? .unverified }
        set { statusRaw = newValue.rawValue }
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
