//
//  DeskClockApp.swift
//  DeskClock
//
//  Created by Oscar PALISSOT on 18/06/2026.
//

import SwiftUI

@main
struct DeskClockApp: App {
    @State private var sessionViewModel = SessionViewModel()
    
    var body: some Scene {
        WindowGroup {
            TabView {
                DashboardView()
                    .tabItem {
                        Label("Tableau de bord", systemImage: "house.fill")
                    }
                
                HistoryView()
                    .tabItem {
                        Label("Historique", systemImage: "clock.fill")
                    }
                
                SettingsView()
                    .tabItem {
                        Label("Réglages", systemImage: "gear")
                    }
            }
            .environment(sessionViewModel)
        }
    }
}
