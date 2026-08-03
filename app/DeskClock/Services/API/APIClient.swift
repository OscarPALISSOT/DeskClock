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
    
    private let tokenRefresher = TokenRefresher()
    
    private init() {
        self.baseURL = URL(string: "https://backend.deskclock.oscarpalissot.fr/v1/")!
        self.session = .shared
        
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }
    
    private func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: Encodable? = nil,
        isRetryAfterRefresh: Bool = false
    ) async throws -> T {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw APIError.invalidURL
        }
        
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = try? KeychainService.read(.accessToken) {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
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
            guard !isRetryAfterRefresh else {
                DebugLoggerService.shared.log("Persistent 401 after refresh on \(path) — server rejected refresh token, logging out")
                await forceLogout()
                throw APIError.unauthorized
            }
            DebugLoggerService.shared.log("401 on \(path) — attempting refresh")
            do {
                try await tokenRefresher.refresh()
            } catch RefreshError.noLocalRefreshToken {
                DebugLoggerService.shared.log("Refresh skipped — local refresh token unreadable")
                throw APIError.unauthorized
            } catch RefreshError.connectivityFailure(let underlying) {
                DebugLoggerService.shared.log("Refresh skipped — network unreachable")
                throw APIError.networkError(underlying)
            } catch {
                DebugLoggerService.shared.log("Refresh rejected by server — \(error)")
                await forceLogout()
                throw APIError.unauthorized
            }
            return try await request(path, method: method, body: body, isRetryAfterRefresh: true)
        default:
            let message = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            throw APIError.httpError(statusCode: http.statusCode, message: message?.message)
        }
    }
    
    func login(email: String, password: String) async throws -> AuthResponseDTO {
        struct Body: Encodable {
            let email: String
            let password: String
        }
        return try await request("auth/email/login", method: "POST", body: Body(email: email, password: password))
    }
    
    func register(email: String, password: String) async throws -> AuthResponseDTO {
        struct Body: Encodable {
            let email: String
            let password: String
        }
        return try await request("auth/email/register", method: "POST", body: Body(email: email, password: password))
    }
    
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
    
    private func forceLogout() async {
        try? KeychainService.delete(.accessToken)
        try? KeychainService.delete(.refreshToken)
        await MainActor.run {
            NotificationCenter.default.post(name: .authDidExpire, object: nil)
        }
    }
    
    func refreshToken(_ refreshToken: String) async throws -> AuthResponseDTO {
        struct Body: Encodable {
            let refresh_token: String
        }
        return try await request("auth/refresh", method: "POST", body: Body(refresh_token: refreshToken), isRetryAfterRefresh: true)
    }
}

extension Notification.Name {
    static let authDidExpire = Notification.Name("authDidExpire")
}

enum RefreshError: Error {
    case connectivityFailure(Error) // couldn't reach the server at all
    case noLocalRefreshToken   // local Keychain read failed — says nothing about whether the token is actually valid
    case serverRejected(Error) // server explicitly rejected the refresh token
}

actor TokenRefresher {
    private var inFlight: Task<Void, Error>?
    
    func refresh() async throws {
        if let inFlight {
            try await inFlight.value
            return
        }
        let task = Task<Void, Error> {
            guard let currentRefreshToken = try? KeychainService.read(.refreshToken) else {
                throw RefreshError.noLocalRefreshToken
            }
            do {
                let dto = try await APIClient.shared.refreshToken(currentRefreshToken)
                try KeychainService.save(dto.access_token, for: .accessToken)
                try KeychainService.save(dto.refresh_token, for: .refreshToken)
            } catch APIError.networkError(let underlying) {
                throw RefreshError.connectivityFailure(underlying)
            } catch {
                throw RefreshError.serverRejected(error)
            }
        }
        inFlight = task
        defer { inFlight = nil }
        try await task.value
    }
}

private struct APIErrorResponse: Decodable {
    let message: String?
}
