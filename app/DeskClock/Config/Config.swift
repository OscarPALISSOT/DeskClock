//
//  Config.swift
//  DeskClock
//
//  Created by Oscar PALISSOT on 04/08/2026.
//

import CoreLocation
import Foundation

enum Config {
    
    static var apiBaseURL: URL {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
              let url = URL(string: raw) else {
            fatalError("Missing or invalid API_BASE_URL — check Secrets.xcconfig")
        }
        return url
    }
    
    static var officeCoordinate: CLLocationCoordinate2D {
        guard let latRaw = Bundle.main.object(forInfoDictionaryKey: "OFFICE_LATITUDE") as? String,
              let lonRaw = Bundle.main.object(forInfoDictionaryKey: "OFFICE_LONGITUDE") as? String,
              let lat = Double(latRaw), let lon = Double(lonRaw) else {
            fatalError("Missing or invalid OFFICE_LATITUDE/LONGITUDE — check Secrets.xcconfig")
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}
