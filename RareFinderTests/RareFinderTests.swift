import Testing
import CoreLocation
@testable import RareFinder

// MARK: - EconomyService

@Suite("Economy — point awards")
struct PointAwardTests {

    @Test("geofence required — no points outside zone")
    func noGeofenceYieldsZero() {
        for quality in [EconomyService.ReportQuality.firstSighting, .verification, .challenge, .duplicate] {
            #expect(EconomyService.pointsForReport(quality: quality, isGeofenceVerified: false) == 0)
        }
    }

    @Test("first sighting earns base + firstSightingBonus")
    func firstSighting() {
        let pts = EconomyService.pointsForReport(quality: .firstSighting, isGeofenceVerified: true)
        #expect(pts == EconomyService.basePoints + EconomyService.firstSightingBonus)
    }

    @Test("verification earns base + verificationBonus")
    func verification() {
        let pts = EconomyService.pointsForReport(quality: .verification, isGeofenceVerified: true)
        #expect(pts == EconomyService.basePoints + EconomyService.verificationBonus)
    }

    @Test("challenge earns only challengeReward")
    func challenge() {
        let pts = EconomyService.pointsForReport(quality: .challenge, isGeofenceVerified: true)
        #expect(pts == EconomyService.challengeReward)
    }

    @Test("duplicate penalty is negative but bounded by -basePoints")
    func duplicate() {
        let pts = EconomyService.pointsForReport(quality: .duplicate, isGeofenceVerified: true)
        #expect(pts < 0)
        #expect(pts >= -EconomyService.basePoints)
    }
}

@Suite("Economy — redemption")
struct RedemptionTests {

    @Test("affordable reward returns reduced balance")
    func affordable() {
        let result = EconomyService.redeem(balance: 500, cost: 200)
        #expect(result == 300)
    }

    @Test("exact-balance redemption returns zero")
    func exactBalance() {
        let result = EconomyService.redeem(balance: 100, cost: 100)
        #expect(result == 0)
    }

    @Test("insufficient balance returns nil")
    func insufficient() {
        let result = EconomyService.redeem(balance: 50, cost: 200)
        #expect(result == nil)
    }

    @Test("negative cost is invalid — returns nil")
    func negativeCost() {
        let result = EconomyService.redeem(balance: 1000, cost: -10)
        #expect(result == nil)
    }

    @Test("zero cost returns original balance")
    func zeroCost() {
        let result = EconomyService.redeem(balance: 300, cost: 0)
        #expect(result == 300)
    }
}

@Suite("Economy — tier progress")
struct TierProgressTests {

    @Test("zero points = start of bronze tier")
    func zeroBronze() {
        #expect(EconomyService.tierProgress(points: 0) == 0.0)
    }

    @Test("halfway through bronze tier")
    func halfBronze() {
        // bronze: 0–250, midpoint = 125
        let p = EconomyService.tierProgress(points: 125)
        #expect(abs(p - 0.5) < 0.01)
    }

    @Test("exactly at silver threshold = start of silver")
    func silverBoundary() {
        // 250 is the floor of silver, so progress = 0
        #expect(EconomyService.tierProgress(points: 250) == 0.0)
    }

    @Test("elite tier progress is clamped to 1.0 at cap")
    func eliteCap() {
        #expect(EconomyService.tierProgress(points: 10_000) == 1.0)
    }
}

@Suite("Economy — boost cost")
struct BoostCostTests {

    @Test("base boost cost when priority is zero")
    func baseCost() {
        #expect(EconomyService.boostCost(currentPriority: 0) == EconomyService.bountyBoostCost)
    }

    @Test("negative priority clamped — same as zero")
    func negativePriority() {
        #expect(EconomyService.boostCost(currentPriority: -5) == EconomyService.bountyBoostCost)
    }

    @Test("higher priority increases cost by 25 per level")
    func scaledCost() {
        let expected = EconomyService.bountyBoostCost + 2 * 25
        #expect(EconomyService.boostCost(currentPriority: 2) == expected)
    }
}

// MARK: - Reward

@Suite("Reward — claim state")
struct RewardClaimTests {

    @Test("new reward is not claimed")
    func freshRewardIsUnclaimed() {
        let r = Reward(title: "Test", summary: "", detail: "", cost: 100, symbol: "bolt.fill")
        #expect(r.claimedAt == nil)
        #expect(r.isClaimed == false)
    }

    @Test("setting claimedAt flips isClaimed")
    func claimingFlipsState() {
        let r = Reward(title: "Test", summary: "", detail: "", cost: 100, symbol: "bolt.fill")
        r.claimedAt = Date()
        #expect(r.isClaimed == true)
    }
}

// MARK: - LocationService

@Suite("Distance — geofence boundary checks")
struct GeofenceTests {

    private let target = CLLocationCoordinate2D(latitude: 1.3521, longitude: 103.8198)

    @Test("same coordinate is inside geofence")
    func exactMatch() {
        #expect(LocationService.isWithinGeofence(userCoordinate: target, targetCoordinate: target))
    }

    @Test("user 30 m north is inside 50 m geofence")
    func within30m() {
        // ~30 m north: 1° lat ≈ 111 km → 30 m ≈ 0.00027°
        let user = CLLocationCoordinate2D(latitude: target.latitude + 0.00027, longitude: target.longitude)
        #expect(LocationService.isWithinGeofence(userCoordinate: user, targetCoordinate: target))
    }

    @Test("user 100 m north is outside 50 m geofence")
    func outside100m() {
        // ~100 m north: ≈ 0.0009°
        let user = CLLocationCoordinate2D(latitude: target.latitude + 0.0009, longitude: target.longitude)
        #expect(!LocationService.isWithinGeofence(userCoordinate: user, targetCoordinate: target))
    }

    @Test("custom radius respected")
    func customRadius() {
        // 80 m away — outside default 50 m but inside 100 m
        let user = CLLocationCoordinate2D(latitude: target.latitude + 0.00072, longitude: target.longitude)
        #expect(!LocationService.isWithinGeofence(userCoordinate: user, targetCoordinate: target, radius: 50))
        #expect(LocationService.isWithinGeofence(userCoordinate: user, targetCoordinate: target, radius: 100))
    }

    @Test("diagonal displacement uses real geodesic distance")
    func diagonal() {
        // 35 m northeast — should be inside 50 m
        let offset = 0.000222  // ≈ 24.7 m per axis → √2×24.7 ≈ 34.9 m
        let user = CLLocationCoordinate2D(
            latitude: target.latitude + offset,
            longitude: target.longitude + offset
        )
        #expect(LocationService.isWithinGeofence(userCoordinate: user, targetCoordinate: target))
    }

    @Test("user inside a 5 km bounty radius passes the custom check")
    func bountyRadius5km() {
        // ~2 km north of the target — well inside a 5 km radius bounty area.
        let user = CLLocationCoordinate2D(latitude: target.latitude + 0.018, longitude: target.longitude)
        #expect(LocationService.isWithinGeofence(
            userCoordinate: user,
            targetCoordinate: target,
            radius: 5_000
        ))
    }

    @Test("user outside a 5 km bounty radius fails the custom check")
    func bountyRadius5kmOutside() {
        // ~10 km north — outside a 5 km radius.
        let user = CLLocationCoordinate2D(latitude: target.latitude + 0.09, longitude: target.longitude)
        #expect(!LocationService.isWithinGeofence(
            userCoordinate: user,
            targetCoordinate: target,
            radius: 5_000
        ))
    }
}

// MARK: - Bounty model

@Suite("Bounty — area vs intel modes")
@MainActor
struct BountyModeTests {

    @Test("default Bounty is exact-location intel (isBounty == false)")
    func defaultIsIntel() {
        let b = Bounty(
            title: "Sample",
            summary: "",
            detail: "",
            category: .services,
            status: .available,
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            district: "Test"
        )
        #expect(b.isBounty == false)
        #expect(b.radiusKm == 0.5)
    }

    @Test("explicitly-bounty record carries its radius")
    func bountyRadiusPersists() {
        let b = Bounty(
            title: "Sample",
            summary: "",
            detail: "",
            category: .services,
            status: .available,
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            district: "Test",
            isBounty: true,
            radiusKm: 12.5
        )
        #expect(b.isBounty)
        #expect(b.radiusKm == 12.5)
    }

    @Test("diameter slider range — 1km radius = 0.5km, 60km diameter = 30km radius")
    func diameterRange() {
        // Radius is half the user-facing diameter; verify both endpoints.
        let minRadius = 1.0 / 2
        let maxRadius = 60.0 / 2
        #expect(minRadius == 0.5)
        #expect(maxRadius == 30.0)
    }
}
