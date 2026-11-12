import SwiftUI
import IPv64

/// Query log: live polling every 3 s while the screen is visible and the app active.
struct NodeDnsLogView: View {
    let nodeId: String

    @Environment(ConnectedNodes.self) private var nodes
    @Environment(\.scenePhase) private var scenePhase

    @State private var rows: [Node64.DNS64LogRow] = []
    @State private var loaded = false
    @State private var pollError: String?
    @State private var live = true
    @State private var query = ""
    @State private var filter: Dns64LogFilter = .all
    @State private var toAllow: Node64.DNS64LogRow?
    @State private var busy = false
    @State private var error: ErrorText?

    private struct PollKey: Equatable {
        var active: Bool, live: Bool, filter: Dns64LogFilter, query: String
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            content.setColorGradient(.orange)
        } else { content }
    }

    private var content: some View {
        List {
            Section {
                Picker("Status", selection: $filter) {
                    Text("All").tag(Dns64LogFilter.all)
                    Text("Blocked").tag(Dns64LogFilter.blocked)
                    Text("Allowed").tag(Dns64LogFilter.allowed)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            if let pollError {
                Section { Text(verbatim: pollError).foregroundStyle(.red) }
            } else if !loaded {
                HStack { Spacer(); ProgressView(); Spacer() }.listRowBackground(Color.clear)
            } else if rows.isEmpty {
                Section { Text("No queries.").foregroundStyle(.secondary) }
            }
            Section {
                ForEach(rows.indices, id: \.self) { logRow(rows[$0]) }
            }
        }
        .navigationTitle("Query log")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Domain or client")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(live ? "Pause live update" : "Resume live update", systemImage: live ? "pause.fill" : "play.fill") {
                    live.toggle()
                }
            }
        }
        .showLoading($busy)
        .errorAlert($error)
        .alert(toAllow?.domain ?? "", isPresented: Binding(get: { toAllow != nil }, set: { if !$0 { toAllow = nil } }),
               presenting: toAllow) { row in
            Button("Allow this domain") { allow(row) }
            Button("Cancel", role: .cancel) {}
        } message: { row in
            Text(dns64AllowMessage(reason: row.reason))
        }
        .task(id: PollKey(active: scenePhase == .active, live: live, filter: filter, query: query)) { await poll() }
    }

    @ViewBuilder private func logRow(_ row: Node64.DNS64LogRow) -> some View {
        if row.status?.rawValue == "blocked" && row.domain != nil {
            Button { toAllow = row } label: { rowContent(row) }.buttonStyle(.plain)
        } else {
            rowContent(row)
        }
    }

    private func rowContent(_ row: Node64.DNS64LogRow) -> some View {
        let who = row.clientName?.nonBlank ?? row.client ?? "–"
        let time = row.date?.formatted(date: .omitted, time: .standard) ?? "–"
        let detail = [who, row.qtype, time].compactMap { $0 }.joined(separator: " · ")
        return HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: row.domain ?? "–").font(.headline).lineLimit(2)
                Text(verbatim: detail).font(.footnote).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 8)
            ProxyTag(tag: dns64StatusTag(row.status?.rawValue))
        }
        .contentShape(Rectangle())
    }

    /// Polls every 3 s while `live`, one fetch otherwise; 300 ms debounce for a typed query.
    private func poll() async {
        guard scenePhase == .active, let dns = nodes.client(for: nodeId)?.dns64 else { return }
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let status = filter.rawStatus.map { Node64.DNS64QueryStatus(rawValue: $0) }
        do {
            if !text.isEmpty { try await Task.sleep(for: .milliseconds(300)) }
            repeat {
                do {
                    rows = try await dns.log(status: status, query: text.isEmpty ? nil : text, limit: 100).rows ?? []
                    pollError = nil
                } catch {
                    try Task.checkCancellation()
                    pollError = ErrorText.node(error).titledText
                }
                loaded = true
                guard live else { return }
                try await Task.sleep(for: .seconds(3))
            } while true
        } catch {
            return
        }
    }

    private func allow(_ row: Node64.DNS64LogRow) {
        guard let domain = row.domain, let dns = nodes.client(for: nodeId)?.dns64 else { return }
        Task {
            busy = true
            defer { busy = false }
            do { _ = try await dns.allowlist.add(domain) } catch { self.error = .node(error) }
        }
    }
}
