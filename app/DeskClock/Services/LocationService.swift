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
    private let officeRadius: CLLocationDistance = 150
    
    private(set) var authorizationStatus: CLAuthorizationStatus
    private var isEntryInFlight = false
    private var isExitInFlight = false
    
    override init() {
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        DebugLoggerService.shared.log("LocationService initialized — initial status: \(describe(authorizationStatus)), local currentSessionID: \(currentSessionID ?? "nil")")
    }
    
    func requestWhenInUseAuthorization() {
        guard authorizationStatus == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }
    
    func requestAlwaysAuthorization() {
        guard authorizationStatus == .authorizedWhenInUse else { return }
        manager.requestAlwaysAuthorization()
    }
    
    func startMonitoringOffice(center: CLLocationCoordinate2D, radius: CLLocationDistance) {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            DebugLoggerService.shared.log("Region monitoring unavailable")
            return
        }
        let office = CLCircularRegion(center: center, radius: radius, identifier: "office")
        office.notifyOnEntry = true
        office.notifyOnExit = true
        manager.startMonitoring(for: office)
        manager.requestState(for: office)
        DebugLoggerService.shared.log("startMonitoring called for 'office'")
    }
    
    // MARK: - Clock-in
    func handleOfficeEntry() {
        guard currentSessionID == nil else {
            DebugLoggerService.shared.log("Entry ignored — session already open locally (id=\(currentSessionID ?? "?"))")
            return
        }
        guard !isEntryInFlight else {
            DebugLoggerService.shared.log("Entry ignored — clock-in already in flight")
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
            DebugLoggerService.shared.log("Clock-in success — session \(session.id)")
        } catch let error as APIError where isTransient(error) && remainingRetries > 0 {
            DebugLoggerService.shared.log("Clock-in transient failure (\(error)) — retrying in 5s, \(remainingRetries) attempt(s) left")
            try? await Task.sleep(for: .seconds(5))
            await attemptClockIn(remainingRetries: remainingRetries - 1)
        } catch {
            DebugLoggerService.shared.log("Clock-in failed — \(error)")
        }
    }
    
    // MARK: - Clock-out
    func handleOfficeExit() {
        guard let sessionID = currentSessionID else {
            DebugLoggerService.shared.log("Exit ignored — no local session to end")
            return
        }
        guard !isExitInFlight else {
            DebugLoggerService.shared.log("Exit ignored — clock-out already in flight")
            return
        }
        isExitInFlight = true
        DebugLoggerService.shared.log("Clock-out launch — session \(sessionID)")
        beginTrackedTask(name: "ClockOut") {
            defer { self.isExitInFlight = false }
            await self.attemptClockOut(sessionID: sessionID, remainingRetries: 2)
        }
    }
    
    private func attemptClockOut(sessionID: String, remainingRetries: Int) async {
        do {
            let _ = try await APIClient.shared.clockOut(sessionId: sessionID, endedAt: Date())
            self.currentSessionID = nil
            DebugLoggerService.shared.log("Clock-out success")
        } catch APIError.httpError(let statusCode, let message) where statusCode == 404 {
            // Server no longer knows this session (closed/deleted manually, or local/server inconsistency) — local state is stale, fix it rather than staying stuck indefinitely.
            DebugLoggerService.shared.log("Session \(sessionID) not found server-side (404: \(message ?? "?")) — clearing local state")
            self.currentSessionID = nil
        } catch let error as APIError where isTransient(error) && remainingRetries > 0 {
            DebugLoggerService.shared.log("Clock-out transient failure (\(error)) — retrying in 5s, \(remainingRetries) attempt(s) left")
            try? await Task.sleep(for: .seconds(5))
            await attemptClockOut(sessionID: sessionID, remainingRetries: remainingRetries - 1)
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
        DebugLoggerService.shared.log("Authorization changed: \(describe(authorizationStatus))")
        switch authorizationStatus {
        case .authorizedWhenInUse:
            self.requestAlwaysAuthorization()
        case .authorizedAlways:
            startMonitoringOffice(center: officeCenter, radius: officeRadius)
        default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        DebugLoggerService.shared.log("didStartMonitoringFor: \(region.identifier)")
        if let region = manager.monitoredRegions.first as? CLCircularRegion {
            DebugLoggerService.shared.log("Monitoring active — center: \(region.center.latitude), \(region.center.longitude), radius: \(region.radius)m")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard region.identifier == "office" else { return }
        DebugLoggerService.shared.log("didEnterRegion")
        handleOfficeEntry()
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard region.identifier == "office" else { return }
        DebugLoggerService.shared.log("didExitRegion")
        handleOfficeExit()
    }
    
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        guard region.identifier == "office" else { return }
        DebugLoggerService.shared.log("didDetermineState: \(describe(state))")
        switch state {
        case .inside: handleOfficeEntry()
        case .outside: handleOfficeExit()
        default: break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        DebugLoggerService.shared.log("monitoringDidFailFor \(region?.identifier ?? "?") — \(error)")
    }
}

private extension LocationService {
    
    var currentSessionID: String? {
        get { UserDefaults.standard.string(forKey: "currentSessionID") }
        set { UserDefaults.standard.set(newValue, forKey: "currentSessionID") }
    }
    
    func describe(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .authorizedAlways: return "authorizedAlways"
        case .authorizedWhenInUse: return "authorizedWhenInUse"
        @unknown default: return "unknown(\(status.rawValue))"
        }
    }
    
    func describe(_ state: CLRegionState) -> String {
        switch state {
        case .inside: return "inside"
        case .outside: return "outside"
        case .unknown: return "unknown"
        @unknown default: return "unknown(\(state.rawValue))"
        }
    }
    
    func beginTrackedTask(name: String, operation: @escaping () async -> Void) {
        var taskID: UIBackgroundTaskIdentifier = .invalid
        taskID = UIApplication.shared.beginBackgroundTask(withName: name) {
            guard taskID != .invalid else { return }
            DebugLoggerService.shared.log("Background task '\(name)' expired before completion")
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
