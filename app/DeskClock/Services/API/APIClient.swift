//
//  APIClient.swift
//  DeskClock
//
//  Created by Oscar PALISSOT on 23/06/2026.
//

import Foundation

final class APIClient {
    static let shared = APIClient()
    
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    
    private init() {
        self.baseURL = URL(string: "https://ton-vps.com/v1")!
        self.session = .shared
        
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }
    
    private func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: Encodable? = nil
    ) async throws -> T {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw APIError.invalidURL
        }
        
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let body {
            req.httpBody = try JSONEncoder().encode(body)
        }
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw APIError.networkError(error)
        }
        
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch http.statusCode {
        case 200...299:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }
        case 401:
            throw APIError.unauthorized
        default:
            let message = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            throw APIError.httpError(statusCode: http.statusCode, message: message?.message)
        }
    }
    
    func getSessions(from: Date? = nil, to: Date? = nil) async throws -> [Session] {
        var path = "/sessions"
        
        var params: [String] = []
        let formatter = ISO8601DateFormatter()
        if let from { params.append("from=\(formatter.string(from: from))") }
        if let to { params.append("to=\(formatter.string(from: to))") }
        if !params.isEmpty { path += "?" + params.joined(separator: "&") }
        
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
        let dto: SessionDTO = try await request("/sessions", method: "POST", body: Body(date: startedAt))
        return dto.toDomain()
    }
    
    func clockOut(sessionId: String, endedAt: Date) async throws -> Session {
        struct Body: Encodable {
            let ended_at: String
            init(date: Date) {
                ended_at = ISO8601DateFormatter().string(from: date)
            }
        }
        let dto: SessionDTO = try await request("/sessions/\(sessionId)", method: "PATCH", body: Body(date: endedAt))
        return dto.toDomain()
    }
}

private struct APIErrorResponse: Decodable {
    let message: String?
}
