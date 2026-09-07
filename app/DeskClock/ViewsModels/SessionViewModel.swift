//
//  SessionViewModel.swift
//  DeskClock
//
//  Created by Oscar PALISSOT on 24/06/2026.
//

import Foundation

@MainActor
@Observable
class SessionViewModel {
    var sessions: [Session] = []
    var isLoading = false
    var error: APIError?
    
    var activeSession: Session? {
        sessions.first { $0.isActive }
    }
    
    func fetchSessions() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            sessions = try await APIClient.shared.getSessions()
        } catch let apiError as APIError {
            error = apiError
        } catch {
            self.error = .networkError(error)
        }
    }
    
    func clockIn() async {
        do {
            let session = try await APIClient.shared.clockIn(startedAt: Date())
            sessions.insert(session, at: 0)
            NotificationService.shared.notifySessionStarted(startedAt: session.startedAt)
        } catch let apiError as APIError {
            error = apiError
        } catch {
            self.error = .networkError(error)
        }
    }
    
    func clockOut() async {
        guard let active = activeSession else { return }
        
        do {
            let updated = try await APIClient.shared.clockOut(
                sessionId: active.id,
                endedAt: Date()
            )
            if let index = sessions.firstIndex(where: { $0.id == active.id }) {
                sessions[index] = updated
            }
            if let endedAt = updated.endedAt {
                let duration = endedAt.timeIntervalSince(updated.startedAt)
                NotificationService.shared.notifySessionEnded(endedAt: endedAt, duration: duration)
            }
        } catch let apiError as APIError {
            error = apiError
        } catch {
            self.error = .networkError(error)
        }
    }
}
