//
//  LogView.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 20.10.25.
//

import SwiftUI
import IPv64

struct LogView: View {
    
    @Binding var popToRootTab: Tabs
    
    @Environment(Session.self) private var session
    @State private var logs: [LogEntry] = []
    @State private var nextBefore: Int?
    @State private var isLoading = false
    @State private var error: ErrorText?
    
    var body: some View {
        if #available(iOS 26.0, *) {
            listView
                .setColorGradient(.orange)
        } else {
            listView
        }
    }
    
    private var listView: some View {
        List {
            Section {
                if logs.isEmpty {
                    if !isLoading {
                        ContentUnavailableView("No logs found", systemImage: "magnifyingglass")
                    }
                } else {
                    ForEach(logs) { log in
                        LogItemView(log: log)
                            .onAppear {
                                if log.id == logs.last?.id { Task { await load(more: true) } }
                            }
                    }
                }
            }
        }
        .showLoading(.constant(isLoading && logs.isEmpty))
        .errorAlert($error)
        .navigationTitle(Tabs.log.labelNew)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load(more: false) }
    }
    
    private func load(more: Bool) async {
        guard !isLoading, !more || nextBefore != nil else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let before = more ? nextBefore : nil
            let page = try await ipv64Retrying { try await session.api.account.logs(before: before) }
            if Task.isCancelled { return }
            logs = more ? logs + page.items : page.items
            nextBefore = page.meta?.nextBefore
        } catch {
            if !Task.isCancelled { self.error = ErrorText(error) }
        }
    }
}

#Preview {
    NavigationStack {
        LogView(popToRootTab: .constant(.domain))
    }
}
