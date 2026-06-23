//
//  HistoryView.swift
//  DeskClock
//
//  Created by Oscar PALISSOT on 20/06/2026.
//

import SwiftUI

struct HistoryView: View {
    @Environment(SessionViewModel.self) private var viewModel
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.sessions.isEmpty {
                    ContentUnavailableView(
                        "Aucune session",
                        systemImage: "clock",
                        description: Text("Vos sessions apparaîtront ici")
                    )
                } else {
                    List(viewModel.sessions) { session in
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
            .task {
                await viewModel.fetchSessions()
            }
            .refreshable {
                await viewModel.fetchSessions()
            }
        }
    }
}
