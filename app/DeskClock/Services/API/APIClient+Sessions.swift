//
//  APIClient+Sessions.swift
//  DeskClock
//
//  Created by Oscar PALISSOT on 17/09/2026.
//

import Foundation

extension APIClient {
    func getSessions(from: Date? = nil, to: Date? = nil) async throws -> [Session] {
        
        let formatter = ISO8601DateFormatter()
        let fromDate = from ?? Calendar.current.startOfWeek(for: Date())
        let toDate = to ?? Date()
        
        let path = "sessions?from=\(formatter.string(from: fromDate))&to=\(formatter.string(from: toDate))"
        
        let dtos: [SessionDTO] = try await request(path)
        return dtos.map { $0.toDomain() }
    }
    
    func clockIn(startedAt: Date) async throws -> Session {
        struct Body: Encodable {
            let started_at: String
            init(date: Date) {
                started_at = ISO8601DateFormatter().string(from: date)
            }
        }
        let dto: SessionDTO = try await request("sessions", method: "POST", body: Body(date: startedAt))
        return dto.toDomain()
    }
    
    func clockOut(sessionId: String, endedAt: Date) async throws -> Session {
        struct Body: Encodable {
            let ended_at: String
            init(date: Date) {
                ended_at = ISO8601DateFormatter().string(from: date)
            }
        }
        let dto: SessionDTO = try await request("sessions/\(sessionId)", method: "PATCH", body: Body(date: endedAt))
        return dto.toDomain()
    }
}
