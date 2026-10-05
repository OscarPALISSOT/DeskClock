//
//  APIClient+Me.swift
//  DeskClock
//
//  Created by Oscar PALISSOT on 17/09/2026.
//

extension APIClient {
    func getMe() async throws -> User {
        try await request("me")
    }
}
