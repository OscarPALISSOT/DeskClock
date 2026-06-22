//
//  SessionDetailView.swift
//  DeskClock
//
//  Created by Oscar PALISSOT on 23/06/2026.
//

import SwiftUI

struct SessionDetailView: View {
    let session: Session
    
    var body: some View {
        List {
            Section {
                LabeledContent("Arrivée") {
                    Text(session.startedAt, format: .dateTime.hour().minute())
                }
                
                if let endedAt = session.endedAt {
                    LabeledContent("Départ") {
                        Text(endedAt, format: .dateTime.hour().minute())
                    }
                } else {
                    LabeledContent("Départ") {
                        Text("Encore au travail")
                            .foregroundStyle(.secondary)
                    }
                }
                
                if let duration = session.duration {
                    LabeledContent("Durée") {
                        Text(Duration.seconds(duration).condensed())
                            .fontWeight(.semibold)
                    }
                }
            } header: {
                Text("Détail")
            }
        }
        .navigationTitle(Text(session.startedAt, format: .dateTime.day().month(.wide)))
        .navigationBarTitleDisplayMode(.inline)
    }
}
