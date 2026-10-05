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
}
