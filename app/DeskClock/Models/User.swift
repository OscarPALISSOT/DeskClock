//
//  User.swift
//  DeskClock
//
//  Created by Oscar PALISSOT on 31/08/2026.
//

import Foundation

enum UserRole: String, Decodable {
    case user
    case tester
}

struct User: Decodable {
    let id: String
    let email: String
    let role: UserRole
    let created_at: Date
}
