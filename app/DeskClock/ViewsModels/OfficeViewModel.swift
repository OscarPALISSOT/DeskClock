//
//  OfficeViewModel.swift
//  DeskClock
//
//  Created by Oscar PALISSOT on 17/09/2026.
//

import CoreLocation
import MapKit
import Observation

@Observable
final class OfficeViewModel {
    enum SaveState: Equatable {
        case idle, saving, failed(String)
    }
    
    private(set) var existingOfficeID: String?
    private(set) var saveState: SaveState = .idle
    private(set) var isLoading = false
    private(set) var error: APIError?
    private(set) var geocodingError: String?
    
    var label: String = ""
    var coordinate: CLLocationCoordinate2D?
    var addressQuery: String = ""
    
    init() {}
    
    func loadExistingOffice() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let offices = try await APIClient.shared.getOffices()
            guard let office = offices.first else {
                DebugLoggerService.shared.log("No office configured server-side")
                return
            }
            existingOfficeID = office.id
            label = office.label
            coordinate = CLLocationCoordinate2D(latitude: office.latitude, longitude: office.longitude)
            DebugLoggerService.shared.log("Office loaded — id: \(office.id), label: \(office.label)")
        } catch let apiError as APIError {
            DebugLoggerService.shared.log("Failed to load office — \(apiError)")
            error = apiError
        } catch {
            DebugLoggerService.shared.log("Failed to load office — \(error)")
            self.error = .networkError(error)
        }
    }
    
    func save() async {
        guard let coordinate else {
            DebugLoggerService.shared.log("Office save blocked — no coordinate selected")
            saveState = .failed("Sélectionnez un emplacement sur la carte")
            return
        }
        saveState = .saving
        DebugLoggerService.shared.log(
            existingOfficeID != nil ? "Office save launch — updating \(existingOfficeID ?? "?")" : "Office save launch — creating"
        )
        
        do {
            let office: Office
            if let id = existingOfficeID {
                office = try await APIClient.shared.updateOffice(
                    id: id,
                    label: label,
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
            } else {
                office = try await APIClient.shared.createOffice(
                    label: label,
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
            }
            
            existingOfficeID = office.id
            OfficeLocationStore.shared.update(
                center: CLLocationCoordinate2D(latitude: office.latitude, longitude: office.longitude)
            )
            DebugLoggerService.shared.log("Office save success — id: \(office.id)")
            saveState = .idle
        } catch let apiError as APIError {
            DebugLoggerService.shared.log("Office save failed — \(apiError)")
            saveState = .failed(String(describing: apiError))
        } catch {
            DebugLoggerService.shared.log("Office save failed — \(error)")
            saveState = .failed(String(describing: error))
        }
    }
    
    func geocodeAddress() async {
        let query = addressQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        
        geocodingError = nil
        
        guard let request = MKGeocodingRequest(addressString: query) else {
            DebugLoggerService.shared.log("Geocoding request could not be built for '\(query)'")
            geocodingError = "Adresse invalide"
            return
        }
        
        do {
            let mapItems = try await request.mapItems
            guard let found = mapItems.first else {
                DebugLoggerService.shared.log("Geocoding returned no results for '\(query)'")
                geocodingError = "Aucun résultat pour cette adresse"
                return
            }
            let newCoordinate = found.location.coordinate
            coordinate = newCoordinate
            DebugLoggerService.shared.log("Geocoded '\(query)' — \(newCoordinate.latitude), \(newCoordinate.longitude)")
        } catch {
            DebugLoggerService.shared.log("Geocoding failed for '\(query)' — \(error)")
            geocodingError = error.localizedDescription
        }
    }
}
