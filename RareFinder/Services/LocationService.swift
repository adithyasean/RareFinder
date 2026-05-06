import Foundation
import CoreLocation
import Observation
import UserNotifications

/// Wraps CoreLocation for bounty discovery, proof-of-presence, and geofencing.
@Observable
@MainActor
final class LocationService: NSObject {
    nonisolated static let geofenceRadius: CLLocationDistance = 50

    private let manager = CLLocationManager()
    private(set) var authorization: CLAuthorizationStatus = .notDetermined
    private(set) var currentLocation: CLLocation?
    private(set) var lastError: String?
    private(set) var monitoredRegions: Set<String> = []

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorization = manager.authorizationStatus
    }

    func requestAuthorization() {
        #if os(macOS)
        manager.requestAlwaysAuthorization()
        #else
        manager.requestWhenInUseAuthorization()
        #endif
    }

    func start() {
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
    }

    /// Pure check — used by report submission and by unit tests.
    nonisolated static func isWithinGeofence(
        userCoordinate: CLLocationCoordinate2D,
        targetCoordinate: CLLocationCoordinate2D,
        radius: CLLocationDistance = geofenceRadius
    ) -> Bool {
        let a = CLLocation(latitude: userCoordinate.latitude, longitude: userCoordinate.longitude)
        let b = CLLocation(latitude: targetCoordinate.latitude, longitude: targetCoordinate.longitude)
        return a.distance(from: b) <= radius
    }

    func isUserInside(_ coordinate: CLLocationCoordinate2D) -> Bool {
        guard let here = currentLocation else { return false }
        return Self.isWithinGeofence(
            userCoordinate: here.coordinate,
            targetCoordinate: coordinate
        )
    }

    /// Registers a CLCircularRegion so the system can deliver entry events even when backgrounded.
    func monitor(bounty: Bounty) {
        #if os(iOS)
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }
        let id = bounty.id.uuidString
        guard !monitoredRegions.contains(id) else { return }
        let region = CLCircularRegion(
            center: bounty.coordinate,
            radius: Self.geofenceRadius,
            identifier: id
        )
        region.notifyOnEntry = true
        region.notifyOnExit = false
        manager.startMonitoring(for: region)
        monitoredRegions.insert(region.identifier)
        #endif
    }

    /// Re-registers geofences for a set of bounties, capped at the system limit (20).
    /// If a current location is known, the closest bounties are picked first.
    func monitorAll(bounties: [Bounty]) {
        #if os(iOS)
        let limit = 20
        let ordered: [Bounty]
        if let here = currentLocation {
            ordered = bounties.sorted {
                let a = CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
                let b = CLLocation(latitude: $1.coordinate.latitude, longitude: $1.coordinate.longitude)
                return a.distance(from: here) < b.distance(from: here)
            }
        } else {
            ordered = bounties
        }
        for bounty in ordered.prefix(limit) {
            monitor(bounty: bounty)
        }
        #endif
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            self.authorization = status
            #if os(macOS)
            if status == .authorizedAlways {
                manager.startUpdatingLocation()
            }
            #else
            if status == .authorizedAlways || status == .authorizedWhenInUse {
                manager.startUpdatingLocation()
            }
            #endif
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor in self.currentLocation = latest }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.lastError = error.localizedDescription }
    }

    #if os(iOS)
    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let circular = region as? CLCircularRegion else { return }
        let identifier = circular.identifier
        Task { @MainActor in
            NotificationCenter.default.post(
                name: .bountyRegionEntered,
                object: nil,
                userInfo: ["id": identifier]
            )
        }
        let content = UNMutableNotificationContent()
        content.title = "Vicinity match"
        content.body = "You're within 50 m of a tracked bounty. Verify and earn Trust Points."
        content.sound = .default
        content.userInfo = ["bountyId": identifier]
        let request = UNNotificationRequest(
            identifier: "rf.region.\(identifier)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    #endif
}

extension Notification.Name {
    static let bountyRegionEntered = Notification.Name("rf.bounty.region.entered")
}
