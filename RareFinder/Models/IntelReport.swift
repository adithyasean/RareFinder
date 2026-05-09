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
    var imageURL: String?
    var isRemote: Bool = false
    var bounty: Bounty?
    @Relationship(deleteRule: .cascade, inverse: \IntelReply.report) var replies: [IntelReply] = []

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
        imageURL: String? = nil,
        isRemote: Bool = false,
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
        self.imageURL = imageURL
        self.isRemote = isRemote
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

@Model
final class IntelReply {
    @Attribute(.unique) var id: UUID
    var hunterName: String
    var hunterSeed: String
    var content: String
    var createdAt: Date
    var isRemote: Bool = false
    var report: IntelReport?
    var parentReplyID: UUID?

    init(
        id: UUID = UUID(),
        hunterName: String,
        hunterSeed: String? = nil,
        content: String,
        createdAt: Date = .now,
        isRemote: Bool = false,
        report: IntelReport? = nil,
        parentReplyID: UUID? = nil
    ) {
        self.id = id
        self.hunterName = hunterName
        self.hunterSeed = hunterSeed ?? hunterName
        self.content = content
        self.createdAt = createdAt
        self.isRemote = isRemote
        self.report = report
        self.parentReplyID = parentReplyID
    }
}
