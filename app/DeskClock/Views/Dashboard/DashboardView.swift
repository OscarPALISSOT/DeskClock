//
//  ContentView.swift
//  DeskClock
//
//  Created by Oscar PALISSOT on 18/06/2026.
//

import SwiftUI

import SwiftUI

struct DashboardView: View {
    let sessions: [Session] = Session.mockSessions
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    WeekProgressView(sessions: sessions)
                } header: {
                    Text("Cette semaine")
                }
                
                Section {
                    ForEach(sessions) { session in
                        SessionRowView(session: session)
                    }
                } header: {
                    Text("Journal")
                }
            }
            .navigationTitle("DeskClock")
        }
    }
}

#Preview {
    DashboardView()
}
