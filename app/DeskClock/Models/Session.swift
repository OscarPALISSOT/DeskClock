//
//  Session.swift
//  DeskClock
//
//  Created by Oscar PALISSOT on 20/06/2026.
//

import Foundation

struct Session: Identifiable, Hashable {
    let id: String
    let startedAt: Date
    let endedAt: Date?
    
    var duration: TimeInterval? {
        guard let endedAt else { return nil }
        return endedAt.timeIntervalSince(startedAt)
    }
    
    var isActive: Bool { endedAt == nil }
}






// mock for dev

extension Session {
    static let mockSessions: [Session] = [
        Session(
            id: "1",
            startedAt: Calendar.current.date(
                bySettingHour: 8, minute: 30, second: 0,
                of: Date()
            )!,
            endedAt: nil  // session en cours
        ),
        Session(
            id: "2",
            startedAt: Calendar.current.date(
                byAdding: .day, value: -1,
                to: Calendar.current.date(
                    bySettingHour: 8, minute: 47, second: 0,
                    of: Date()
                )!
            )!,
            endedAt: Calendar.current.date(
                byAdding: .day, value: -1,
                to: Calendar.current.date(
                    bySettingHour: 12, minute: 03, second: 0,
                    of: Date()
                )!
            )!
        ),
        Session(
            id: "3",
            startedAt: Calendar.current.date(
                byAdding: .day, value: -1,
                to: Calendar.current.date(
                    bySettingHour: 13, minute: 58, second: 0,
                    of: Date()
                )!
            )!,
            endedAt: Calendar.current.date(
                byAdding: .day, value: -1,
                to: Calendar.current.date(
                    bySettingHour: 18, minute: 2, second: 0,
                    of: Date()
                )!
            )!
        ),
        Session(
            id: "4",
            startedAt: Calendar.current.date(
                byAdding: .day, value: -2,
                to: Calendar.current.date(
                    bySettingHour: 8, minute: 21, second: 0,
                    of: Date()
                )!
            )!,
            endedAt: Calendar.current.date(
                byAdding: .day, value: -2,
                to: Calendar.current.date(
                    bySettingHour: 12, minute: 28, second: 0,
                    of: Date()
                )!
            )!
        ),
        Session(
            id: "5",
            startedAt: Calendar.current.date(
                byAdding: .day, value: -2,
                to: Calendar.current.date(
                    bySettingHour: 14, minute: 17, second: 0,
                    of: Date()
                )!
            )!,
            endedAt: Calendar.current.date(
                byAdding: .day, value: -2,
                to: Calendar.current.date(
                    bySettingHour: 18, minute: 32, second: 0,
                    of: Date()
                )!
            )!
        )
    ]
}
