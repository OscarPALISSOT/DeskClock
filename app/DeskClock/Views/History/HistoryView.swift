//
//  HistoryView.swift
//  DeskClock
//
//  Created by Oscar PALISSOT on 20/06/2026.
//

import SwiftUI

struct HistoryView: View {
    let sessions: [Session] = Session.mockSessions
    
    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "Aucune session",
                        systemImage: "clock",
                        description: Text("Vos sessions apparaîtront ici")
                    )
                } else {
                    List(sessions) { session in
                        NavigationLink(value: session) {
                            SessionRowView(session: session)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Historique")
            .navigationDestination(for: Session.self) { session in
                SessionDetailView(session: session)
            }
        }
    }
}
