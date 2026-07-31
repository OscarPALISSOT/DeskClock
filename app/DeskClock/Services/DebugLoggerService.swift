//
//  DebugLoggerService.swift
//  DeskClock
//
//  Created by Oscar PALISSOT on 31/07/2026.
//


import Foundation

final class DebugLoggerService {
    static let shared = DebugLoggerService()

    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.deskclock.debuglogger")
    private let formatter: DateFormatter

    private init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = documents.appendingPathComponent("debug.log")
        formatter = DateFormatter()
        formatter.dateFormat = "dd/MM HH:mm:ss"
    }

    func log(_ message: String) {
        queue.async {
            let line = "[\(self.formatter.string(from: Date()))] \(message)\n"
            print(line)

            guard let data = line.data(using: .utf8) else { return }
            if FileManager.default.fileExists(atPath: self.fileURL.path) {
                if let handle = try? FileHandle(forWritingTo: self.fileURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    try? handle.close()
                }
            } else {
                try? data.write(to: self.fileURL)
            }
        }
    }

    func readAll() -> String {
        (try? String(contentsOf: fileURL, encoding: .utf8)) ?? "Aucun log pour l'instant."
    }

    func clear() {
        queue.async { try? FileManager.default.removeItem(at: self.fileURL) }
    }
}
