//
//  NotificationService.swift
//  DeskClock
//
//  Created by Oscar PALISSOT on 06/09/2026.
//

import UserNotifications

// Schedules local notifications for work session start/end events.
final class NotificationService {
    static let shared = NotificationService()
    let center = UNUserNotificationCenter.current()
    
    private init() {}
    
    func requestAuthorizationIfNeeded() async {
        let settings = await center.notificationSettings()
        
        guard settings.authorizationStatus != .authorized else { return }
        do {
            try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            DebugLoggerService.shared.log("Notification authorization request failed: \(error)")
        }
    }
    
    func notifySessionStarted(startedAt: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Début de la session de travail"
        content.body = "Session commencé à \(startedAt.formatted( .dateTime.hour().minute()))"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        center.add(request)
    }
    
    func notifySessionEnded(endedAt: Date, duration: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "Fin de la session de travail"
        content.body = "Session terminée à \(endedAt.formatted( .dateTime.hour().minute())) pour une durée de \(Self.formattedDuration(duration))"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        center.add(request)
    }
    
    private static func formattedDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "?"
    }
}
