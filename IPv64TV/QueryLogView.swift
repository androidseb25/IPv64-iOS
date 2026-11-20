import SwiftUI
import IPv64

/// One query of the log; shared with the dashboard's "Recent queries" card.
struct TVLogRow: View {
    let row: Node64.DNS64LogRow
    var detailed = false
    @AppStorage(TVSettings.streamingMode) private var streaming = false

    private var color: Color {
        switch row.status?.rawValue {
        case "allowed", "cached": .green
        case "blocked": .red
        case "error": .orange
        default: .gray
        }
    }

    /// Localized badge text; an unknown server status is shown as sent.
    private var statusText: Text {
        switch row.status?.rawValue {
        case "allowed": Text("Allowed")
        case "cached": Text("Cached")
        case "blocked": Text("Blocked")
        case "error": Text("Error")
        default: Text(verbatim: (row.status?.rawValue ?? "?").capitalized)
        }
    }

    var body: some View {
        HStack(spacing: 20) {
            statusText
                .font(.caption.bold())
                .lineLimit(1).minimumScaleFactor(0.6)
                .foregroundStyle(.white)
                .frame(width: 120)
                .padding(.vertical, 6)
                .background(color, in: Capsule())
            VStack(alignment: .leading, spacing: 2) {
                Text(row.domain.map { streaming ? Streaming.mask($0) : $0 } ?? "–").lineLimit(1)
                Text((row.clientName ?? row.client).map { streaming ? Streaming.mask($0) : $0 } ?? "–")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 12)
            if detailed {
                Text(row.qtype ?? "").font(.caption).foregroundStyle(.secondary)
                if let ms = row.ms { Text("\(ms.formatted(.number.precision(.fractionLength(0)))) ms").font(.caption).foregroundStyle(.secondary) }
            }
            if let date = row.date {
                Text(date, format: .dateTime.hour().minute().second()).monospacedDigit().foregroundStyle(.secondary)
            }
        }
    }
}

struct QueryLogView: View {
    @Environment(TVSession.self) private var session
    @State private var rows: [Node64.DNS64LogRow] = []
    @State private var filter: Node64.DNS64QueryStatus?
    @State private var error: String?
    @State private var loading = false
    /// Refresh and retry restart the one load task, so a slow older load can't land after a filter change.
    @State private var reloads = 0
    @State private var denied = Set<String>()
    @State private var allowed = Set<String>()
    @State private var selected: Node64.DNS64LogRow?
    @State private var actionError: String?
    @AppStorage(TVSettings.streamingMode) private var streaming = false

    private struct LoadKey: Equatable { let filter: Node64.DNS64QueryStatus?; let reloads: Int; let generation: Int }

    var body: some View {
        // Same header position as the dashboard (below the floating tab bar), filter and refresh on the right.
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 30) {
                Label("Query log", systemImage: "list.bullet.rectangle").font(.largeTitle.bold()).lineLimit(1)
                Spacer(minLength: 0)
                Picker("Filter", selection: $filter) {
                    Text("All").tag(Node64.DNS64QueryStatus?.none)
                    Text("Blocked").tag(Node64.DNS64QueryStatus?.some(.blocked))
                    Text("Allowed").tag(Node64.DNS64QueryStatus?.some(.allowed))
                }
                .pickerStyle(.segmented)
                .frame(width: 520)
                Button { reloads += 1 } label: {
                    if loading { ProgressView() } else { Label("Refresh", systemImage: "arrow.clockwise") }
                }
            }
            .focusSection()  // up from any row reaches filter and Refresh on the right
            if let error {
                ContentUnavailableView {
                    Label("Could not load the log", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
            } else {
                // Own focus look (TVRowButtonStyle): the system list platter washes out the coloured badges.
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                            Button { if row.domain != nil { selected = row } } label: { TVLogRow(row: row, detailed: true) }
                                .buttonStyle(TVRowButtonStyle())
                        }
                    }
                    .padding(.vertical, 12)
                }
                .tvFocusRoom()
            }
        }
        .tvPage()
        .confirmationDialog(selected?.domain.map { streaming ? Streaming.mask($0) : $0 } ?? "", isPresented: Binding(get: { selected != nil }, set: { if !$0 { selected = nil } }),
                            titleVisibility: .visible, presenting: selected) { row in
            let domain = row.domain ?? ""
            let blocked = row.status?.rawValue == "blocked"
            if denied.contains(domain) {
                Button("Remove from block list") { change(domain) { try await $0.denylist.remove(domain) } }
            } else if blocked {
                Button("Allow this domain") { change(domain) { _ = try await $0.allowlist.add(domain) } }
            }
            if allowed.contains(domain) {
                Button("Remove from allow list") { change(domain) { try await $0.allowlist.remove(domain) } }
            } else if !blocked && !denied.contains(domain) {
                Button("Block this domain", role: .destructive) { change(domain) { _ = try await $0.denylist.add(domain) } }
            }
            Button("Cancel", role: .cancel) {}
        } message: { row in
            if denied.contains(row.domain ?? "") || allowed.contains(row.domain ?? "") {
                Text("This domain is on your own block or allow list.")
            } else if row.status?.rawValue == "blocked" {
                // The reason can name a list URL: hidden in streaming mode.
                if let reason = row.reason, !streaming {
                    Text("Blocked by \(reason). Allow this domain and its subdomains for all clients?")
                } else {
                    Text("Blocked. Allow this domain and its subdomains for all clients?")
                }
            } else {
                Text("Block this domain and its subdomains for all clients?")
            }
        }
        .alert("Error", isPresented: Binding(get: { actionError != nil }, set: { if !$0 { actionError = nil } })) {
        } message: { Text(actionError ?? "") }
        .task(id: LoadKey(filter: filter, reloads: reloads, generation: session.generation)) { await load() }
    }

    private func load() async {
        guard let client = session.client else { return }
        loading = true
        defer { if !Task.isCancelled { loading = false } }  // a cancelled load must not hide the new load's spinner
        do {
            let dns = client.dns64
            async let log = dns.log(status: filter, limit: 100)
            async let deny = dns.denylist.list()
            async let allow = dns.allowlist.list()
            // The lists only drive the dialog: an older node without them still shows the log.
            let (d, a) = (((try? await deny) ?? []), ((try? await allow) ?? []))
            rows = try await log.rows ?? []
            denied = Set(d.compactMap(\.domain))
            allowed = Set(a.compactMap(\.domain))
            error = nil
        } catch {
            if Task.isCancelled { return }
            self.error = Streaming.errorText(error, streaming: streaming)
        }
    }

    private func change(_ domain: String, _ action: @escaping (Node64.DNS64) async throws -> Void) {
        guard let dns = session.client?.dns64 else { return }
        Task {
            do { try await action(dns); reloads += 1 } catch { actionError = Streaming.errorText(error, streaming: streaming) }
        }
    }
}
