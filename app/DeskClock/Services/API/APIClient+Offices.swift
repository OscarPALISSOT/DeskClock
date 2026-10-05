//
//  APIClient+Offices.swift
//  DeskClock
//
//  Created by Oscar PALISSOT on 17/09/2026.
//

extension APIClient {
    func getOffices() async throws -> [Office] {
        let dtos: [OfficeDTO] = try await request("offices")
        return dtos.map { $0.toDomain() }
    }
    
    func createOffice(label: String, latitude: Double, longitude: Double) async throws -> Office {
        struct Body: Encodable {
            let label: String
            let latitude: Double
            let longitude: Double
        }
        let dto: OfficeDTO = try await request(
            "offices",
            method: "POST",
            body: Body(label: label, latitude: latitude, longitude: longitude)
        )
        return dto.toDomain()
    }
    
    func updateOffice(id: String, label: String, latitude: Double, longitude: Double) async throws -> Office {
        struct Body: Encodable {
            let label: String
            let latitude: Double
            let longitude: Double
        }
        let dto: OfficeDTO = try await request(
            "offices/\(id)",
            method: "PATCH",
            body: Body(label: label, latitude: latitude, longitude: longitude)
        )
        return dto.toDomain()
    }
}
