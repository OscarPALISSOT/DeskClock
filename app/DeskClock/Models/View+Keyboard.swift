//
//  View+Keyboard.swift
//  DeskClock
//
//  Created by Oscar PALISSOT on 01/07/2026.
//

import SwiftUI

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }
}
