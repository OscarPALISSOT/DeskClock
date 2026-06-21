//
//  HistoryView.swift
//  DeskClock
//
//  Created by Oscar PALISSOT on 20/06/2026.
//

import SwiftUI

struct HistoryView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Historique",
                systemImage: "clock",
                description: Text("L'historique apparaîtra ici")
            )
            .navigationTitle("Historique")
        }
    }
}
