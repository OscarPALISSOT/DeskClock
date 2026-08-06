//
//  DeskClockWidget.swift
//  DeskClockWidget
//
//  Created by Oscar PALISSOT on 02/08/2026.
//

import WidgetKit
import SwiftUI

// Snapshot of what the widget displays at a given point in time.
struct DeskClockEntry: TimelineEntry {
    let date: Date
    let isAuthenticated: Bool
    let todayStartedAt: Date?     // nil if not clocked in today
    let weekTotalSeconds: TimeInterval
}


struct DeskClockWidget: Widget {
    let kind: String = "DeskClockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DeskClockProvider()) { entry in
            if #available(iOS 17.0, *) {
                DeskClockWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                DeskClockWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("DeskClock")
        .description("Résumé de ta présence au bureau.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    DeskClockWidget()
} timeline: {
    DeskClockEntry(date: .now, isAuthenticated: true, todayStartedAt: .now, weekTotalSeconds: 14_400)
}
