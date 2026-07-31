
import CoreLocation
import Observation
import UIKit

@Observable
final class LocationService: NSObject {
    private let manager = CLLocationManager()
    private let officeCenter = CLLocationCoordinate2D(latitude: 45.188323, longitude: 5.712538)
    private let officeRadius: CLLocationDistance = 80

    private(set) var authorizationStatus: CLAuthorizationStatus
    private var isEntryInFlight = false
    private var isExitInFlight = false

    override init() {
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        DebugLoggerService.shared.log("🚀 LocationService instancié — statut initial: \(describe(authorizationStatus)), currentSessionID local: \(currentSessionID ?? "nil")")
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
            DebugLoggerService.shared.log("❌ Region monitoring indisponible")
            return
        }
        let office = CLCircularRegion(center: center, radius: radius, identifier: "office")
        office.notifyOnEntry = true
        office.notifyOnExit = true
        manager.startMonitoring(for: office)
        manager.requestState(for: office)
        DebugLoggerService.shared.log("📍 startMonitoring appelé pour 'office'")
    }

    func handleOfficeEntry() {
        guard currentSessionID == nil else {
            DebugLoggerService.shared.log("⛔️ Entrée ignorée — session déjà ouverte localement (id=\(currentSessionID ?? "?"))")
            return
        }
        guard !isEntryInFlight else {
            DebugLoggerService.shared.log("⛔️ Entrée ignorée — clock-in déjà en cours")
            return
        }
        isEntryInFlight = true
        DebugLoggerService.shared.log("▶️ Clock-in lancé")
        beginTrackedTask(name: "ClockIn") {
            defer { self.isEntryInFlight = false }
            do {
                let session = try await APIClient.shared.clockIn(startedAt: Date())
                self.currentSessionID = session.id
                DebugLoggerService.shared.log("✅ Clock-in réussi — session \(session.id)")
            } catch {
                DebugLoggerService.shared.log("❌ Clock-in échoué — \(error)")
            }
        }
    }

    func handleOfficeExit() {
        guard let sessionID = currentSessionID else {
            DebugLoggerService.shared.log("⛔️ Sortie ignorée — aucune session locale ouverte")
            return
        }
        guard !isExitInFlight else {
            DebugLoggerService.shared.log("⛔️ Sortie ignorée — clock-out déjà en cours")
            return
        }
        isExitInFlight = true
        DebugLoggerService.shared.log("▶️ Clock-out lancé — session \(sessionID)")
        beginTrackedTask(name: "ClockOut") {
            defer { self.isExitInFlight = false }
            do {
                let _ = try await APIClient.shared.clockOut(sessionId: sessionID, endedAt: Date())
                self.currentSessionID = nil
                DebugLoggerService.shared.log("✅ Clock-out réussi")
            } catch APIError.httpError(let statusCode, let message) where statusCode == 404 {
                DebugLoggerService.shared.log("⚠️ Session \(sessionID) introuvable côté serveur (404: \(message ?? "?")) — état local remis à zéro")
                self.currentSessionID = nil
            } catch {
                DebugLoggerService.shared.log("❌ Clock-out échoué — \(error)")
            }
        }
    }
}

extension LocationService: CLLocationManagerDelegate {

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        DebugLoggerService.shared.log("🔐 Autorisation changée: \(describe(authorizationStatus))")
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
        DebugLoggerService.shared.log("✅ didStartMonitoringFor: \(region.identifier)")
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard region.identifier == "office" else { return }
        DebugLoggerService.shared.log("🔵 didEnterRegion")
        handleOfficeEntry()
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard region.identifier == "office" else { return }
        DebugLoggerService.shared.log("🔴 didExitRegion")
        handleOfficeExit()
    }

    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        guard region.identifier == "office" else { return }
        DebugLoggerService.shared.log("🟡 didDetermineState: \(describe(state))")
        if state == .inside {
            handleOfficeEntry()
        }
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        DebugLoggerService.shared.log("❌ monitoringDidFailFor \(region?.identifier ?? "?") — \(error)")
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
        @unknown default: return "inconnu(\(status.rawValue))"
        }
    }

    func describe(_ state: CLRegionState) -> String {
        switch state {
        case .inside: return "inside"
        case .outside: return "outside"
        case .unknown: return "unknown"
        @unknown default: return "inconnu(\(state.rawValue))"
        }
    }

    func beginTrackedTask(name: String, operation: @escaping () async -> Void) {
        var taskID: UIBackgroundTaskIdentifier = .invalid
        taskID = UIApplication.shared.beginBackgroundTask(withName: name) {
            guard taskID != .invalid else { return }
            DebugLoggerService.shared.log("⏰ Background task '\(name)' expirée avant la fin")
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
