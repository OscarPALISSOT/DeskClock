//
//  ContentView.swift
//  DeskClock
//
//  Created by Oscar PALISSOT on 25/06/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var sessionViewModel = SessionViewModel()
    @Environment(AuthService.self) private var authService
    
    var body: some View {
        if authService.isAuthenticated {
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
        } else {
            LoginView()
        }
    }
}
