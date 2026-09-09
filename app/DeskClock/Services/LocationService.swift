//
//  LocationService.swift
//  DeskClock
//
//  Created by Oscar PALISSOT on 31/07/2026.
//

import CoreLocation
import Observation
import UIKit

@Observable
final class LocationService: NSObject {
    private let manager = CLLocationManager()
    private let officeCenter = Config.officeCoordinate
    private let officeRadius: CLLocationDistance = 80
    
    private(set) var authorizationStatus: CLAuthorizationStatus
    private var isEntryInFlight = false
    private var isExitInFlight = false
    
    override init() {
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        DebugLoggerService.shared.log(
            "LocationService initialized — initial status: \(describe(authorizationStatus)), local currentSessionID: \(currentSessionID ?? "nil")"
        )
    }
    
    // MARK: - IOS user authorization
    func requestWhenInUseAuthorization() {
        guard authorizationStatus == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }
    
    func requestAlwaysAuthorization() {
        guard authorizationStatus == .authorizedWhenInUse else { return }
        manager.requestAlwaysAuthorization()
    }
    
    // MARK: - Start monitor office
    func startMonitoringOffice(
        center: CLLocationCoordinate2D,
        radius: CLLocationDistance
    ) {
        guard
            CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self)
        else {
            DebugLoggerService.shared.log("Region monitoring unavailable")
            return
        }
        let office = CLCircularRegion(
            center: center,
            radius: radius,
            identifier: "office"
        )
        office.notifyOnEntry = true
        office.notifyOnExit = true
        manager.startMonitoring(for: office)
        manager.requestState(for: office)
        DebugLoggerService.shared.log("startMonitoring called for 'office'")
    }
    
    // MARK: - Significant Location Change monitoring (SLC)
    //
    // SLC wakes the app on ~500m movement or cell/Wi-Fi handover, even from a
    // killed/suspended state, at very low power cost. Used here as an ACTIVE
    // trigger to force a fresh region check instead of waiting passively for
    // the next boundary-crossing event or the next app launch.
    
    func startSignificantLocationMonitoring() {
        guard CLLocationManager.significantLocationChangeMonitoringAvailable()
        else {
            DebugLoggerService.shared.log(
                "significantLocationChangeMonitoring not available"
            )
            return
        }
        manager.startMonitoringSignificantLocationChanges()
        DebugLoggerService.shared.log("SLC monitoring started")
    }
    
    // MARK: - Clock-in
    func handleOfficeEntry() {
        guard currentSessionID == nil else {
            DebugLoggerService.shared.log(
                "Entry ignored — session already open locally (id=\(currentSessionID ?? "?"))"
            )
            return
        }
        guard !isEntryInFlight else {
            DebugLoggerService.shared.log(
                "Entry ignored — clock-in already in flight"
            )
            return
        }
        isEntryInFlight = true
        DebugLoggerService.shared.log("Clock-in launch")
        beginTrackedTask(name: "ClockIn") {
            defer { self.isEntryInFlight = false }
            await self.attemptClockIn(remainingRetries: 2)
        }
    }
    
    private func attemptClockIn(remainingRetries: Int) async {
        do {
            let session = try await APIClient.shared.clockIn(startedAt: Date())
            self.currentSessionID = session.id
            DebugLoggerService.shared.log(
                "Clock-in success — session \(session.id)"
            )
            NotificationService.shared.notifySessionStarted(startedAt: session.startedAt)
        } catch let error as APIError
                    where isTransient(error) && remainingRetries > 0
        {
            DebugLoggerService.shared.log(
                "Clock-in transient failure (\(error)) — retrying in 5s, \(remainingRetries) attempt(s) left"
            )
            try? await Task.sleep(for: .seconds(5))
            await attemptClockIn(remainingRetries: remainingRetries - 1)
        } catch {
            DebugLoggerService.shared.log("Clock-in failed — \(error)")
        }
    }
    
    // MARK: - Clock-out
    func handleOfficeExit() {
        guard let sessionID = currentSessionID else {
            DebugLoggerService.shared.log(
                "Exit ignored — no local session to end"
            )
            return
        }
        guard !isExitInFlight else {
            DebugLoggerService.shared.log(
                "Exit ignored — clock-out already in flight"
            )
            return
        }
        isExitInFlight = true
        DebugLoggerService.shared.log("Clock-out launch — session \(sessionID)")
        beginTrackedTask(name: "ClockOut") {
            defer { self.isExitInFlight = false }
            await self.attemptClockOut(
                sessionID: sessionID,
                remainingRetries: 2
            )
        }
    }
    
    private func attemptClockOut(sessionID: String, remainingRetries: Int) async
    {
        do {
            let updated = try await APIClient.shared.clockOut(
                sessionId: sessionID,
                endedAt: Date()
            )
            self.currentSessionID = nil
            DebugLoggerService.shared.log("Clock-out success")
            if let endedAt = updated.endedAt {
                let duration = endedAt.timeIntervalSince(updated.startedAt)
                NotificationService.shared.notifySessionEnded(endedAt: endedAt, duration: duration)
            }
        } catch APIError.httpError(let statusCode, let message)
                    where statusCode == 404
        {
            // Server no longer knows this session (closed/deleted manually, or local/server inconsistency) — local state is stale, fix it rather than staying stuck indefinitely.
            DebugLoggerService.shared.log(
                "Session \(sessionID) not found server-side (404: \(message ?? "?")) — clearing local state"
            )
            self.currentSessionID = nil
        } catch let error as APIError
                    where isTransient(error) && remainingRetries > 0
        {
            DebugLoggerService.shared.log(
                "Clock-out transient failure (\(error)) — retrying in 5s, \(remainingRetries) attempt(s) left"
            )
            try? await Task.sleep(for: .seconds(5))
            await attemptClockOut(
                sessionID: sessionID,
                remainingRetries: remainingRetries - 1
            )
        } catch {
            DebugLoggerService.shared.log("Clock-out failed — \(error)")
        }
    }
    
    // Treats network and auth failures as worth a short retry.
    // After the refresh-flow fix, both can result from a local hiccup (bad connectivity, Keychain read failing at the wrong moment) rather than a permanent problem with the request itself.
    // A genuine rejection surfaces later, after retries are exhausted, and is not retried further.
    private func isTransient(_ error: APIError) -> Bool {
        switch error {
        case .networkError, .unauthorized: return true
        default: return false
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        DebugLoggerService.shared.log(
            "Authorization changed: \(describe(authorizationStatus))"
        )
        switch authorizationStatus {
        case .authorizedWhenInUse:
            self.requestAlwaysAuthorization()
        case .authorizedAlways:
            startMonitoringOffice(center: officeCenter, radius: officeRadius)
            startSignificantLocationMonitoring()
        case .denied, .restricted:
            DebugLoggerService.shared.log(
                "Authorization revoked or restricted (\(describe(authorizationStatus))) — monitoring will be stopped by iOS"
            )
        default:
            break
        }
    }
    
    func locationManager(
        _ manager: CLLocationManager,
        didStartMonitoringFor region: CLRegion
    ) {
        DebugLoggerService.shared.log(
            "didStartMonitoringFor: \(region.identifier)"
        )
        if let region = manager.monitoredRegions.first as? CLCircularRegion {
            DebugLoggerService.shared.log(
                "Monitoring active — center: \(region.center.latitude), \(region.center.longitude), radius: \(region.radius)m"
            )
        }
    }
    
    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else { return }
        
        let now = Date()
        let key = "lastKnownLocationTimestamp"
        let previousTimestamp =
        UserDefaults.standard.object(forKey: key) as? Date
        let dormancy = previousTimestamp.map { now.timeIntervalSince($0) }
        UserDefaults.standard.set(now, forKey: key)
        
        DebugLoggerService.shared.log(
            "[SLC] location update — accuracy: \(Int(location.horizontalAccuracy))m, "
            + "age: \(Int(now.timeIntervalSince(location.timestamp)))s, "
            + "dormancy: \(dormancy.map { "\(Int($0))s" } ?? "n/a")"
        )
        
        guard
            let office = manager.monitoredRegions.first(where: {
                $0.identifier == "office"
            })
        else {
            DebugLoggerService.shared.log(
                "[SLC] no monitored 'office' region — skipping requestState"
            )
            return
        }
        manager.requestState(for: office)
    }
    
    func locationManager(
        _ manager: CLLocationManager,
        didEnterRegion region: CLRegion
    ) {
        guard region.identifier == "office" else { return }
        logLocationContext(prefix: "didEnterRegion")
        DebugLoggerService.shared.log("didEnterRegion")
        handleOfficeEntry()
    }
    
    func locationManager(
        _ manager: CLLocationManager,
        didExitRegion region: CLRegion
    ) {
        guard region.identifier == "office" else { return }
        logLocationContext(prefix: "didExitRegion")
        DebugLoggerService.shared.log("didExitRegion")
        handleOfficeExit()
    }
    
    func locationManager(
        _ manager: CLLocationManager,
        didDetermineState state: CLRegionState,
        for region: CLRegion
    ) {
        guard region.identifier == "office" else { return }
        logLocationContext(prefix: "didDetermineState: \(describe(state))")
        DebugLoggerService.shared.log("didDetermineState: \(describe(state))")
        switch state {
        case .inside: handleOfficeEntry()
        case .outside: handleOfficeExit()
        default: break
        }
    }
    
    func locationManager(
        _ manager: CLLocationManager,
        monitoringDidFailFor region: CLRegion?,
        withError error: Error
    ) {
        DebugLoggerService.shared.log(
            "monitoringDidFailFor \(region?.identifier ?? "?") — \(error)"
        )
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DebugLoggerService.shared.log("Location manager failed — \(error)")
    }
    
}

extension LocationService {
    
    fileprivate var currentSessionID: String? {
        get { UserDefaults.standard.string(forKey: "currentSessionID") }
        set { UserDefaults.standard.set(newValue, forKey: "currentSessionID") }
    }
    
    fileprivate func describe(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .authorizedAlways: return "authorizedAlways"
        case .authorizedWhenInUse: return "authorizedWhenInUse"
        @unknown default: return "unknown(\(status.rawValue))"
        }
    }
    
    fileprivate func describe(_ state: CLRegionState) -> String {
        switch state {
        case .inside: return "inside"
        case .outside: return "outside"
        case .unknown: return "unknown"
        @unknown default: return "unknown(\(state.rawValue))"
        }
    }
    
    fileprivate func logLocationContext(prefix: String) {
        guard let location = manager.location else {
            DebugLoggerService.shared.log(
                "\(prefix) — no cached location available"
            )
            return
        }
        let staleness = Int(Date().timeIntervalSince(location.timestamp))
        DebugLoggerService.shared.log(
            "\(prefix) — accuracy: \(Int(location.horizontalAccuracy))m, staleness: \(staleness)s"
        )
    }
    
    fileprivate func beginTrackedTask(
        name: String,
        operation: @escaping () async -> Void
    ) {
        var taskID: UIBackgroundTaskIdentifier = .invalid
        taskID = UIApplication.shared.beginBackgroundTask(withName: name) {
            guard taskID != .invalid else { return }
            DebugLoggerService.shared.log(
                "Background task '\(name)' expired before completion"
            )
            UIApplication.shared.endBackgroundTask(taskID)
            taskID = .invalid
        }
        Task {
            defer {
                if taskID != .invalid {
                    UIApplication.shared.endBackgroundTask(taskID)
                    taskID = .invalid
                }
            }
            await operation()
        }
    }
}
