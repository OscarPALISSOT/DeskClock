//
//  APIClient+Auth.swift
//  DeskClock
//
//  Created by Oscar PALISSOT on 17/09/2026.
//

extension APIClient {
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
    
    func refreshToken(_ refreshToken: String) async throws -> AuthResponseDTO {
        struct Body: Encodable {
            let refresh_token: String
        }
        return try await request("auth/refresh", method: "POST", body: Body(refresh_token: refreshToken), isRetryAfterRefresh: true)
    }
    
}
