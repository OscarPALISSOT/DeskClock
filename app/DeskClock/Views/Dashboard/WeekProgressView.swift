//
//  WeekProgressView.swift
//  DeskClock
//
//  Created by Oscar PALISSOT on 20/06/2026.
//

import SwiftUI

struct WeekProgressView: View {
    let sessions: [Session]
    
    var totalSeconds: Double {
        sessions
            .compactMap { $0.duration }
            .reduce(0, +)
    }
    
    let targetSeconds: Double = 37.5 * 3600
    
    func labelHours(seconds: Double) -> String {
        return String(Duration.seconds(seconds).formatted(.time(pattern: .hourMinute)))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(labelHours(seconds: totalSeconds))h / \(labelHours(seconds: targetSeconds))h")
                .font(.title)
                .fontWeight(.bold)
            
            ProgressView(value: totalSeconds, total: targetSeconds)
                .tint(.blue)
            
            Text("\(labelHours(seconds:targetSeconds - totalSeconds))h restantes")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}
