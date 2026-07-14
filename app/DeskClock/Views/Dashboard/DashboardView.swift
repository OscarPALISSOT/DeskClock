//
//  ContentView.swift
//  DeskClock
//
//  Created by Oscar PALISSOT on 18/06/2026.
//

import SwiftUI

struct DashboardView: View {
    @Environment(SessionViewModel.self) private var viewModel
    @Environment(LocationService.self) private var locationService
    

    var body: some View {
        NavigationStack {
            List {
                Section {
                    WeekProgressView(sessions: viewModel.sessions)
                } header: {
                    Text("Cette semaine")
                }
                
                Section {
                    ForEach(viewModel.sessions) { session in
                        SessionRowView(session: session)
                    }
                } header: {
                    Text("Journal")
                }
            }
            .navigationTitle("DeskClock")
            .task {
                await viewModel.fetchSessions()
            }
            .refreshable {
                await viewModel.fetchSessions()
            }
            .alert("Erreur", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") { viewModel.error = nil }
            } message: {
                Text(viewModel.error?.localizedDescription ?? "")
            }
            .onAppear {
                locationService.requestWhenInUseAuthorization()
            }
        }
    }
}


#Preview {
    DashboardView()
        .environment(SessionViewModel())
        .environment(LocationService())
}
