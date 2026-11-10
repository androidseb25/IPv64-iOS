import SwiftUI
import IPv64

/// "Logs" (spec 04 §13): newest first, cursor paging.
struct LogsView: View {
    @Environment(Session.self) private var session

    @State private var items: [LogEntry] = []
    @State private var nextBefore: Int?
    @State private var retentionDays: Int?
    @State private var loadedOnce = false
    @State private var isLoading = false
    @State private var pageFailed = false
    @State private var generation = 0

    var body: some View {
        List {
            ForEach(items) { entry in
                ListRow(verbatim: entry.title ?? "", subtitle: subtitle(entry), subtitleLineLimit: 6)
                    .onAppear { if items.suffix(2).contains(where: { $0.id == entry.id }) { Task { await loadMore() } } }
            }
            if !items.isEmpty { footer }
        }
        .overlay {
            if !loadedOnce && isLoading {
                LoadingView()
            } else if loadedOnce && items.isEmpty {
                if pageFailed {
                    ContentUnavailableView {
                        Label("Logs could not be loaded.", systemImage: "exclamationmark.triangle")
                    } actions: {
                        Button("Retry") { Task { await reload() } }
                    }
                } else {
                    ContentUnavailableView("No logs yet.", systemImage: "exclamationmark.bubble")
                }
            }
        }
        .navigationTitle("Logs")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await reload() }
        .task(id: session.accountRevision) { await reload() }
    }

    @ViewBuilder
    private var footer: some View {
        if isLoading {
            ProgressView().frame(maxWidth: .infinity)
        } else if pageFailed {
            Button("Retry") { Task { await loadMore(force: true) } }.frame(maxWidth: .infinity)
        } else if nextBefore == nil, let retentionDays {
            Text("Logs are kept for \(retentionDays) days")
                .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
        }
    }

    private func subtitle(_ entry: LogEntry) -> String {
        var lines: [String] = []
        if let message = entry.message, !message.isEmpty { lines.append(message) }
        lines.append(Formatters.germanTime(entry.time, fallback: ""))
        return lines.joined(separator: "\n")
    }

    private func reload() async {
        generation += 1
        items = []
        nextBefore = nil
        pageFailed = false
        loadedOnce = false
        await fetch(before: nil)
    }

    private func loadMore(force: Bool = false) async {
        guard let cursor = nextBefore, !isLoading, !pageFailed || force else { return }
        await fetch(before: cursor)
    }

    private func fetch(before: Int?) async {
        let mine = generation
        isLoading = true
        pageFailed = false
        defer { if mine == generation { isLoading = false; loadedOnce = true } }
        do {
            let page = try await ipv64Retrying { try await session.api.account.logs(before: before) }
            guard mine == generation else { return }
            let known = Set(items.map(\.id))
            items += page.items.filter { !known.contains($0.id) }
            nextBefore = page.meta?.nextBefore
            retentionDays = page.meta?.retentionDays ?? retentionDays
        } catch {
            if mine == generation, !(error is CancellationError) { pageFailed = true }
        }
    }
}
