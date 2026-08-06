//
//  DeskClockWidgetEntryView.swift
//  DeskClock
//
//  Created by Oscar PALISSOT on 05/08/2026.
//


import SwiftUI

struct DeskClockWidgetEntryView: View {
    var entry: DeskClockProvider.Entry

    var body: some View {
        if !entry.isAuthenticated {
            VStack(spacing: 4) {
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                Text("Reconnecte-toi")
                    .font(.caption)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("DeskClock")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let startedAt = entry.todayStartedAt {
                    Label {
                        Text(startedAt, format: .dateTime.hour().minute())
                    } icon: {
                        Image(systemName: "figure.walk.arrival")
                    }
                } else {
                    Text("Pas encore arrivé")
                        .font(.subheadline)
                }

                Spacer()

                Text("Semaine : \(formattedDuration(entry.weekTotalSeconds))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        }
    }

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: seconds) ?? "—"
    }
}
