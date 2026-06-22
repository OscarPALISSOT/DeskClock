//
//  Duration+Formatting.swift
//  DeskClock
//
//  Created by Oscar PALISSOT on 22/06/2026.
//

import Foundation

extension Duration {
    func condensed(style: DurationFormatStyle = .condensed) -> String {
        switch style {
        case .condensed:
            let totalSeconds = Int(self.components.seconds)
            let hours = totalSeconds / 3600
            let minutes = (totalSeconds % 3600) / 60
            return "\(hours)h \(minutes)m"
        case .hoursOnly:
            let hours = Int(self.components.seconds) / 3600
            return "\(hours)h"
        }
    }
    
    enum DurationFormatStyle {
        case condensed   // "14h 23m"
        case hoursOnly   // "14h"
    }
}
