//
//  DebugLogView.swift
//  DeskClock
//
//  Created by Oscar PALISSOT on 31/07/2026.
//

import SwiftUI

struct DebugLogView: View {
    @State private var logText = ""
    @State private var showShareSheet = false

    var body: some View {
        ScrollView {
            Text(logText)
                .font(.system(.footnote, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .textSelection(.enabled)
        }
        .navigationTitle("Logs de debug")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Rafraîchir") { refresh() }
                    Button("Partager") { showShareSheet = true }
                    Button("Effacer", role: .destructive) {
                        DebugLoggerService.shared.clear()
                        refresh()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear { refresh() }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [logText])
        }
    }

    private func refresh() {
        logText = DebugLoggerService.shared.readAll()
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
