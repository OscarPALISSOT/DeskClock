//
//  SessionRowView.swift
//  DeskClock
//
//  Created by Oscar PALISSOT on 20/06/2026.
//

import SwiftUI

struct SessionRowView: View {
    let session: Session
    
    private var dayTitle: String {
        let calendar = Calendar.current
        let date = session.startedAt
        
        if calendar.isDateInToday(date) { return "Aujourd'hui" }
        if calendar.isDateInYesterday(date) { return "Hier" }
        
        if let days = calendar.dateComponents([.day],
                                              from: calendar.startOfDay(for: date),
                                              to: calendar.startOfDay(for: .now)).day,
           days < 7 {
            return date.formatted(.dateTime.weekday(.wide)
                .locale(Locale(identifier: "fr_FR"))).capitalized
        }
        
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide)
            .locale(Locale(identifier: "fr_FR"))).capitalized
    }
    
    var body: some View {
        HStack {
            VStack {
                Text(session.startedAt, format: .dateTime.weekday(.abbreviated))
                    .font(.caption2)
                    .fontWeight(.semibold)
                Text(session.startedAt, format: .dateTime.day())
                    .font(.title3)
                    .fontWeight(.bold)
            }
            .frame(width: 44)
            .padding(8)
            .background(.blue.opacity(0.1))
            .foregroundStyle(.blue)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading) {
                Text(dayTitle)
                    .font(.headline)
                Text("\(session.startedAt, format: .dateTime.hour().minute()) \(session.isActive ? "" : " - \(session.endedAt!, format: .dateTime.hour().minute())")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if let duration = session.duration {
                Text(Duration.seconds(duration).condensed())
                    .font(.headline)
                    .fontWeight(.semibold)
            } else {
                Text("En cours")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
    }
}
