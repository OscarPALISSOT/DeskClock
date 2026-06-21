//
//  SettingsView.swift
//  DeskClock
//
//  Created by Oscar PALISSOT on 20/06/2026.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Réglages",
                systemImage: "gear",
                description: Text("Les réglages apparaîtront ici")
            )
            .navigationTitle("Réglages")
        }
    }
}
