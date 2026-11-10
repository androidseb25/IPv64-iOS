import SwiftUI
import IPv64

/// Query log (spec 03 §8): live polling while the screen is visible and the app active.
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
    @State private var confirm: ConfirmRequest?
    @State private var busy: LocalizedStringKey?
    @State private var error: ErrorText?

    private struct PollKey: Equatable {
        var active: Bool, live: Bool, filter: Dns64LogFilter, query: String, nodeId: String
    }

    var body: some View {
        Group {
            if nodes.access(for: nodeId) == nil {
                ContentUnavailableView("No direct connection to this node.", systemImage: "network.slash")
            } else {
                list
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
        .confirmDialog($confirm)
        .loadingOverlay(busy != nil, text: busy ?? "Updating...")
        .errorAlert($error)
        .task(id: PollKey(active: scenePhase == .active, live: live, filter: filter, query: query, nodeId: nodeId)) {
            await poll()
        }
    }

    private var list: some View {
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
                Section { Text(verbatim: pollError).foregroundStyle(Color.ipv64Red) }
            } else if !loaded {
                Section { HStack { Spacer(); ProgressView(); Spacer() } }.listRowBackground(Color.clear)
            } else if rows.isEmpty {
                Section { Text("No queries.").foregroundStyle(.secondary) }
            }
            Section {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in logRow(row) }
            }
        }
    }

    @ViewBuilder private func logRow(_ row: Node64.DNS64LogRow) -> some View {
        let canAllow = row.status?.rawValue == "blocked" && row.domain != nil
        if canAllow {
            Button { ask(row) } label: { content(row) }.buttonStyle(.plain)
        } else {
            content(row)
        }
    }

    private func content(_ row: Node64.DNS64LogRow) -> some View {
        let chip = dns64StatusChip(row.status?.rawValue)
        let subtitle = dns64LogSubtitle(
            time: row.date.map(Formatters.clock) ?? "–", clientName: row.clientName, client: row.client,
            qtype: row.qtype, upstream: row.upstream, ms: row.ms, status: row.status?.rawValue,
            domain: row.domain, reason: row.reason)
        return HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: row.domain ?? "–").font(.headline).lineLimit(2)
                Text(verbatim: subtitle).font(.footnote).foregroundStyle(.secondary).lineLimit(4)
            }
            Spacer(minLength: 8)
            StatusChip(verbatim: chip.label, color: chip.tone.color)
        }
        .contentShape(Rectangle())
    }

    /// Polls every 3 s while `live`, a single fetch otherwise; 300 ms debounce for a typed query.
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
                    loaded = true
                } catch {
                    try Task.checkCancellation()
                    pollError = ErrorText.node(error).titledText
                    loaded = true
                }
                guard live else { return }
                try await Task.sleep(for: .seconds(3))
            } while true
        } catch {
            return
        }
    }

    private func ask(_ row: Node64.DNS64LogRow) {
        guard let domain = row.domain else { return }
        confirm = ConfirmRequest(title: domain, message: dns64AllowMessage(reason: row.reason),
                                 confirmLabel: String(localized: "Allow this domain")) {
            Task {
                busy = "Updating..."
                defer { busy = nil }
                do { _ = try await nodes.client(for: nodeId)?.dns64.allowlist.add(domain) } catch { self.error = .node(error) }
            }
        }
    }
}

extension Dns64StatusTone {
    var color: Color {
        switch self {
        case .red: .ipv64Red
        case .orange: .ipv64Orange
        case .green: .ipv64Green
        case .gray: .ipv64Gray
        }
    }
}
