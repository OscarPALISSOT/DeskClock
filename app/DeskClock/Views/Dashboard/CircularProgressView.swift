//
//  CircularProgressView.swift
//  DeskClock
//
//  Created by Oscar PALISSOT on 22/06/2026.
//

import SwiftUI

struct CircularProgressView: View {
    let value: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.blue.opacity(0.15), lineWidth: 8)
            
            Circle()
                .trim(from: 0, to: value)
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))  // démarre à 12h
            
            Text("\(Int(value * 100))%")
                .font(.headline)
                .fontWeight(.bold)
        }
        .frame(width: 64, height: 64)
    }
}
