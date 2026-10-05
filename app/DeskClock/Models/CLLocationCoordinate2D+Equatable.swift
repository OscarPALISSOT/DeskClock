//
//  CLLocationCoordinate2D+Equatable.swift
//  DeskClock
//
//  Created by Oscar PALISSOT on 05/10/2026.
//

import CoreLocation

// CLLocationCoordinate2D does not conform to Equatable out of the box.
// Needed for SwiftUI's onChange(of:) to detect coordinate changes.
extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
