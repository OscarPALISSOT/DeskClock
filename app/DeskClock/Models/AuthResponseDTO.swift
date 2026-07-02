//
//  SessionDTO.swift
//  DeskClock
//
//  Created by Oscar PALISSOT on 23/06/2026.
//

import Foundation

struct AuthResponseDTO: Decodable {
    let access_token: String
    let refresh_token: String
    let expires_in: Int
}
