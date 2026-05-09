import Foundation
import CoreLocation
import Observation
import UserNotifications

/// Wraps CoreLocation for bounty discovery, proof-of-presence, and geofencing.
///
/// Proximity alerts work via two complementary paths so they fire reliably
/// even when the OS doesn't deliver a `didEnterRegion` event in time
/// (simulator quirks, foreground races, "When In Use" auth):
///
///   1. **System region monitoring** — `CLCircularRegion`s are registered for
///      every "scanned" bounty. When the OS reports entry we post a high-
///      priority local notification.
///   2. **Foreground distance fallback** — every location update we walk
///      every monitored region and check the actual distance ourselves. If
///      the user crossed into a radius we haven't already alerted on, we
///      post the same notification. This catches the case where the OS
///      didn't fire (common on the simulator) and the case where the user
///      armed the scanner while *already* inside the radius.
@Observable
@MainActor
final class LocationService: NSObject {
    nonisolated static let geofenceRadius: CLLocationDistance = 50

    private let manager = CLLocationManager()
    private(set) var authorization: CLAuthorizationStatus = .notDetermined
    private(set) var currentLocation: CLLocation?
    private(set) var lastError: String?
    private(set) var monitoredRegions: Set<String> = []

    /// Mapping of region identifier → centre + radius, kept locally so the
    /// foreground fallback doesn't depend on `manager.monitoredRegions`
    /// (which is not always populated immediately on the simulator).
    private struct WatchedZone {
        let center: CLLocationCoordinate2D
        let radius: CLLocationDistance
        let title: String
    }
    private var watched: [String: WatchedZone] = [:]
    /// Identifiers we've already fired an entry alert for during this app
    /// session — prevents repeat-pings every location tick.
    private var alerted: Set<String> = []

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 10
        manager.pausesLocationUpdatesAutomatically = false
        authorization = manager.authorizationStatus
    }

    /// Requests "When In Use" first; once granted, escalates to "Always" so
    /// region monitoring continues to deliver entry events while the app is
    /// backgrounded. iOS shows a separate prompt for the upgrade.
    func requestAuthorization() {
        #if os(macOS)
        manager.requestAlwaysAuthorization()
        #else
        switch authorization {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        default:
            break
        }
        #endif
    }

    func start() {
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
    }

    /// Stops all background monitoring, clears tracked zones, and removes
    /// pending vicinity notifications from the system tray.
    func reset() {
        #if os(iOS)
        // Stop the OS-level region monitoring
        for region in manager.monitoredRegions {
            manager.stopMonitoring(for: region)
        }
        #endif
        
        // Stop GPS updates
        manager.stopUpdatingLocation()
        
        // Clear internal state
        watched.removeAll()
        monitoredRegions.removeAll()
        alerted.removeAll()
        currentLocation = nil
        
        // Clear the notification tray
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        
        // Refresh authorization status
        authorization = manager.authorizationStatus
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

    /// Registers a CLCircularRegion so the system can deliver entry events
    /// even when backgrounded. Bounty-area items use their `radiusKm`;
    /// exact-location intel uses the default 50 m geofence.
    func monitor(bounty: Bounty) {
        #if os(iOS)
        let id = bounty.id.uuidString
        let radius: CLLocationDistance = bounty.isBounty
            ? max(bounty.radiusKm * 1000, 100)   // bounty area; clamp tiny radii
            : Self.geofenceRadius

        // Track locally for the foreground fallback regardless of OS support.
        watched[id] = WatchedZone(center: bounty.coordinate, radius: radius, title: bounty.title)
        monitoredRegions.insert(id)

        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }
        let region = CLCircularRegion(
            center: bounty.coordinate,
            radius: radius,
            identifier: id
        )
        region.notifyOnEntry = true
        region.notifyOnExit = false
        manager.startMonitoring(for: region)

        // Ask the OS for the current state — if the user is already inside,
        // CoreLocation calls `didDetermineState` with `.inside` and we treat
        // that as an entry event. Without this, arming a scanner while
        // already in the zone never fires.
        manager.requestState(for: region)

        // Belt-and-braces: if a fix is already known, run the foreground
        // check immediately so the alert isn't gated on the next GPS update.
        if let here = currentLocation { evaluateForegroundEntry(at: here) }
        #endif
    }

    /// Re-registers geofences for a set of bounties, capped at the system
    /// limit (20). If a current location is known, the closest bounties are
    /// picked first so we monitor the most relevant zones.
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

    // MARK: - Internal

    /// Fires the entry notification for the given identifier, broadcasting on
    /// `NotificationCenter` for in-app listeners and scheduling a UN local
    /// notification for the system tray. De-duped by `alerted`.
    fileprivate func fireEntryAlert(identifier: String) {
        guard !alerted.contains(identifier) else { return }
        alerted.insert(identifier)

        let title = watched[identifier]?.title

        NotificationCenter.default.post(
            name: .bountyRegionEntered,
            object: nil,
            userInfo: ["id": identifier]
        )

        let content = UNMutableNotificationContent()
        content.title = "Vicinity match"
        if let title {
            content.body = "You're inside the \(title) zone. Tap to verify and earn Trust Points."
        } else {
            content.body = "You've entered a tracked bounty zone. Verify and earn Trust Points."
        }
        content.sound = .defaultCritical
        content.interruptionLevel = .timeSensitive
        content.userInfo = ["bountyId": identifier]
        let request = UNNotificationRequest(
            identifier: "rf.region.\(identifier)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    /// Walks every locally-tracked zone and fires an alert for any the user
    /// is currently inside. This is the foreground fallback that does not
    /// depend on the OS region-monitoring callbacks.
    fileprivate func evaluateForegroundEntry(at location: CLLocation) {
        for (id, zone) in watched {
            guard !alerted.contains(id) else { continue }
            let centre = CLLocation(latitude: zone.center.latitude, longitude: zone.center.longitude)
            if location.distance(from: centre) <= zone.radius {
                fireEntryAlert(identifier: id)
            }
        }
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
            // Once "When In Use" is granted, transparently escalate to Always
            // so background region monitoring works.
            if status == .authorizedWhenInUse {
                manager.requestAlwaysAuthorization()
            }
            #endif
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor in
            self.currentLocation = latest
            self.evaluateForegroundEntry(at: latest)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.lastError = error.localizedDescription }
    }

    #if os(iOS)
    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let circular = region as? CLCircularRegion else { return }
        let identifier = circular.identifier
        Task { @MainActor in self.fireEntryAlert(identifier: identifier) }
    }

    /// `requestState(for:)` reports `.inside` if the user was already in the
    /// region at the time monitoring started — without this, arming the
    /// scanner while standing on the spot never fires.
    nonisolated func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        guard let circular = region as? CLCircularRegion, state == .inside else { return }
        let identifier = circular.identifier
        Task { @MainActor in self.fireEntryAlert(identifier: identifier) }
    }
    #endif
}

extension Notification.Name {
    static let bountyRegionEntered = Notification.Name("rf.bounty.region.entered")
}
