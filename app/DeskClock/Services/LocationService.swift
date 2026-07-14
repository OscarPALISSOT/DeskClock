//
//  LocationService.swift
//  DeskClock
//
//  Created by Oscar PALISSOT on 03/07/2026.
//

import CoreLocation
import Observation
import UIKit

@Observable
final class LocationService: NSObject {
    private let manager = CLLocationManager()
    private let officeCenter = CLLocationCoordinate2D(latitude: 45.188323, longitude: 5.712538)
    private let officeRadius: CLLocationDistance = 80
    
    private(set) var authorizationStatus: CLAuthorizationStatus
    
    override init() {
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
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
        if CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) {
            let office = CLCircularRegion(center: center, radius: radius, identifier: "office")
            office.notifyOnEntry = true
            office.notifyOnExit = true
            manager.startMonitoring(for: office)
            manager.requestState(for: office)
        }
    }
    
    private var isEntryInFlight = false
    private var isExitInFlight = false
    
    func handleOfficeEntry() {
        guard currentSessionID == nil, !isEntryInFlight  else { return }
        isEntryInFlight = true
        beginTrackedTask(name: "ClockIn") {
            defer { self.isEntryInFlight = false }
            do {
                let session = try await APIClient.shared.clockIn(startedAt: Date())
                self.currentSessionID = session.id
            } catch {
                print(error)
            }
        }
    }
    
    func handleOfficeExit() {
        guard let sessionID = currentSessionID, !isExitInFlight else { return }
        isExitInFlight = true
        beginTrackedTask(name: "ClockOut") {
            defer { self.isExitInFlight = false }
            do {
                let _ = try await APIClient.shared.clockOut(sessionId: sessionID, endedAt: Date())
                self.currentSessionID = nil
            } catch {
                print(error)
            }
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        switch authorizationStatus {
        case .authorizedWhenInUse:
            self.requestAlwaysAuthorization()
        case .authorizedAlways:
            startMonitoringOffice(center: officeCenter, radius: officeRadius)
        default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard region.identifier == "office" else { return }
        handleOfficeEntry()
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard region.identifier == "office" else { return }
        handleOfficeExit()
    }
    
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        guard region.identifier == "office" else { return }
        if state == .inside {
            handleOfficeEntry()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print(error)
    }
}

private extension LocationService {
    
    var currentSessionID: String? {
        get { UserDefaults.standard.string(forKey: "currentSessionID") }
        set { UserDefaults.standard.set(newValue, forKey: "currentSessionID") }
    }
    
    // Wrap an async task in a background task assertion to guarante iOS let enought time to the request to finish.
    func beginTrackedTask(name: String, operation: @escaping () async -> Void) {
        var taskID: UIBackgroundTaskIdentifier = .invalid
        taskID = UIApplication.shared.beginBackgroundTask(withName: name) {
            guard taskID != .invalid else { return }
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
