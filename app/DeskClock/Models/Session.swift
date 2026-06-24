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
