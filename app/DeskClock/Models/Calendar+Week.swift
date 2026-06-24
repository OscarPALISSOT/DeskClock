//
//  Calendar+Week.swift
//  DeskClock
//
//  Created by Oscar PALISSOT on 25/06/2026.
//

import Foundation

extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components) ?? date
    }
}
