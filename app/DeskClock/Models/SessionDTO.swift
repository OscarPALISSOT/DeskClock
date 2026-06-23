//
//  SessionDTO.swift
//  DeskClock
//
//  Created by Oscar PALISSOT on 23/06/2026.
//

import Foundation

struct SessionDTO: Decodable {
    let id: String
    let userId: String
    let startedAt: Date
    let endedAt: Date?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case createdAt = "created_at"
    }
    
    func toDomain() -> Session {
        Session(id: id, startedAt: startedAt, endedAt: endedAt)
    }
}
