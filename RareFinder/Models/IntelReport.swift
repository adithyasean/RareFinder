import Foundation
import SwiftData
import CoreLocation

@Model
final class IntelReport {
    @Attribute(.unique) var id: UUID
    var hunterName: String
    var hunterSeed: String
    var note: String
    var statusRaw: String
    var district: String
    var latitude: Double
    var longitude: Double
    var upvotes: Int
    var downvotes: Int
    var createdAt: Date
    var symbol: String
    var pointsAwarded: Int
    var bounty: Bounty?

    init(
        id: UUID = UUID(),
        hunterName: String,
        hunterSeed: String? = nil,
        note: String,
        status: BountyStatus,
        district: String,
        coordinate: CLLocationCoordinate2D,
        upvotes: Int = 0,
        downvotes: Int = 0,
        symbol: String = "mappin.and.ellipse",
        pointsAwarded: Int = 50,
        createdAt: Date = .now,
        bounty: Bounty? = nil
    ) {
        self.id = id
        self.hunterName = hunterName
        self.hunterSeed = hunterSeed ?? hunterName
        self.note = note
        self.statusRaw = status.rawValue
        self.district = district
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.upvotes = upvotes
        self.downvotes = downvotes
        self.symbol = symbol
        self.pointsAwarded = pointsAwarded
        self.createdAt = createdAt
        self.bounty = bounty
    }

    var status: BountyStatus {
        get { BountyStatus(rawValue: statusRaw) ?? .unverified }
        set { statusRaw = newValue.rawValue }
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
