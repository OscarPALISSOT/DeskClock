//
//  DeskClockApp.swift
//  DeskClock
//
//  Created by Oscar PALISSOT on 18/06/2026.
//

import SwiftUI

@main
struct DeskClockApp: App {
    @State private var authService = AuthService()
    @State private var locationService = LocationService()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authService)
                .environment(locationService)
        }
    }
}
