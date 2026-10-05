//
//  OfficeLocationStore.swift
//  DeskClock
//
//  Created by Oscar PALISSOT on 17/09/2026.
//

import CoreLocation
import Observation

@Observable
final class OfficeLocationStore {
    static let shared = OfficeLocationStore()

    private(set) var center: CLLocationCoordinate2D?

    private init() {
        let defaults = UserDefaults.standard
        guard
            let latitude = defaults.object(forKey: "officeLatitude") as? Double,
            let longitude = defaults.object(forKey: "officeLongitude") as? Double
        else {
            DebugLoggerService.shared.log("OfficeLocationStore initialized — no cached office")
            return
        }
        center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        DebugLoggerService.shared.log("OfficeLocationStore initialized — cached office at \(latitude), \(longitude)")
    }

    var isConfigured: Bool { center != nil }

    func update(center: CLLocationCoordinate2D) {
        let defaults = UserDefaults.standard
        defaults.set(center.latitude, forKey: "officeLatitude")
        defaults.set(center.longitude, forKey: "officeLongitude")
        self.center = center
        DebugLoggerService.shared.log("Office location updated — \(center.latitude), \(center.longitude)")
        NotificationCenter.default.post(name: .officeLocationDidChange, object: nil)
    }
}

// MARK: - Check if office in UserDefault is sync with backend
extension OfficeLocationStore {
    @discardableResult
    func syncFromServer() async throws -> Bool {
        let offices = try await APIClient.shared.getOffices()
        guard let office = offices.first else {
            DebugLoggerService.shared.log("Office sync — no office server-side")
            return false
        }

        let newCenter = CLLocationCoordinate2D(latitude: office.latitude, longitude: office.longitude)
        if let current = center, current.latitude == newCenter.latitude, current.longitude == newCenter.longitude {
            DebugLoggerService.shared.log("Office sync — cache already up to date")
            return false
        }

        DebugLoggerService.shared.log("Office sync — new office found, updating cache")
        update(center: newCenter)
        return true
    }
}

// MARK: - Notify LocationService to re-arm
extension Notification.Name {
    static let officeLocationDidChange = Notification.Name("officeLocationDidChange")
}
