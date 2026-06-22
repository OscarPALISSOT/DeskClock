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
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(Duration.seconds(totalSeconds).condensed(style: .hoursOnly)) / \(Duration.seconds(targetSeconds).condensed(style: .hoursOnly))")
                    .font(.title)
                    .fontWeight(.bold)
                
                
                Text("\(Duration.seconds(targetSeconds - totalSeconds).condensed()) restantes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
            
            Spacer()
            
            CircularProgressView(value: totalSeconds / targetSeconds)
        }
        
    }
}
