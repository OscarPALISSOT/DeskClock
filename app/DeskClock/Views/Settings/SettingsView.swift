//
//  SettingsView.swift
//  DeskClock
//
//  Created by Oscar PALISSOT on 20/06/2026.
//

import SwiftUI

struct SettingsView: View {
    @Environment(AuthService.self) private var authService
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Se déconnecter", role: .destructive) {
                        authService.logout()
                    }
                }
            }
            .navigationTitle("Réglages")
        }
    }
}
