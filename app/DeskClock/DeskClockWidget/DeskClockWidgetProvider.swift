//
//  DeskClockWidgetEntry.swift
//  DeskClock
//
//  Created by Oscar PALISSOT on 05/08/2026.
//

import WidgetKit

struct DeskClockProvider: TimelineProvider {

    func placeholder(in context: Context) -> DeskClockEntry {
        DeskClockEntry(date: .now, isAuthenticated: true, todayStartedAt: .now, weekTotalSeconds: 14_400)
    }

    func getSnapshot(in context: Context, completion: @escaping (DeskClockEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        Task {
            completion(await fetchEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DeskClockEntry>) -> Void) {
        Task {
            let entry = await fetchEntry()
            // Authenticated: refresh at a reasonable cadence. Not authenticated:
            // back off further — a real login has to happen in the app first,
            // retrying sooner won't help.
            let nextReload = Date.now.addingTimeInterval(entry.isAuthenticated ? 30 * 60 : 60 * 60)
            completion(Timeline(entries: [entry], policy: .after(nextReload)))
        }
    }

    private func fetchEntry() async -> DeskClockEntry {
        do {
            let sessions = try await APIClient.shared.getSessions() // default: start of week -> now
            let startOfToday = Calendar.current.startOfDay(for: .now)

            let todaySession = sessions
                .filter { $0.startedAt >= startOfToday }
                .min(by: { $0.startedAt < $1.startedAt })
            let weekTotal = sessions.reduce(0.0) { total, session in
                total + (session.endedAt ?? .now).timeIntervalSince(session.startedAt)
            }

            return DeskClockEntry(
                date: .now,
                isAuthenticated: true,
                todayStartedAt: todaySession?.startedAt,
                weekTotalSeconds: weekTotal
            )
        } catch {
            // TODO: narrow this once APIError distinguishes "unauthenticated"
            // from other failures — right now a transient network hiccup and
            // an expired session both fall back to the same state. Safe
            // default for a surface with no interactive retry, but worth
            // refining once you're back on APIError.
            return DeskClockEntry(date: .now, isAuthenticated: false, todayStartedAt: nil, weekTotalSeconds: 0)
        }
    }
}
