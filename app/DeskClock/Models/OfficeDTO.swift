//
//  OfficeDTO.swift
//  DeskClock
//
//  Created by Oscar PALISSOT on 15/09/2026.
//

import Foundation

struct OfficeDTO: Decodable {
    let id: String
    let userId: String
    let label: String
    let latitude: Double
    let longitude: Double
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case label
        case latitude
        case longitude
        case createdAt = "created_at"
    }

    func toDomain() -> Office {
        Office(id: id, label: label, latitude: latitude, longitude: longitude)
    }
}
