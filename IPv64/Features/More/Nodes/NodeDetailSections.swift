import SwiftUI
import IPv64

// List sections of the node detail (spec 04 §4, sections 1-8). Part of NodeDetailView so they read its state.
extension NodeDetailView {
    func detailList(_ info: NodeInfo) -> some View {
        List {
            headerSection(info)
            Section { statTiles(info) }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            if tracking != nil {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        ProgressView().progressViewStyle(.linear)
                        Text("Waiting for the node to run the command…").font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            modulesSection(info)
            if !directOnly { checksSection(info) }
            if isLocal, live.status != nil { NodeLogsSection(lines: live.logs) }
            if !directOnly { historySection(info) }
            detailsSection(info)
        }
    }

    // MARK: 1 Header

    private func headerSection(_ info: NodeInfo) -> some View {
        let version = (localNode?.version?.nonBlank ?? info.version?.nonBlank).map { "v" + $0 }
        let source: String? = if let config = access {
            String(localized: "Direct \(LocalNodeURL.host(of: config.url) ?? config.url)")
        } else {
            [String(localized: "Cloud"), Formatters.ago(info.lastSeen).map { String(localized: "seen \($0)") }]
                .compactMap { $0 }.joined(separator: " · ")
        }
        let subtitle = [version, source].compactMap { $0 }.joined(separator: " · ")
        return Section {
            if isLocal && live.failing {
                Text(verbatim: live.rejected ?? String(localized: "Connection lost — retrying…")).foregroundStyle(Color.ipv64Red)
                Button("Edit connection") { router.sheet = .directAccess(nodeId: nodeId) }
            }
            if let other = otherNodeId {
                Text("This address belongs to another node (\(other)). Forget the direct connection and connect again.")
                    .foregroundStyle(Color.ipv64Red)
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: displayName)
                    Text(verbatim: subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                headerChip(info)
            }
            if isLocal { liveLines }
            else {
                Button { router.sheet = .directAccess(nodeId: nodeId) } label: {
                    ListRow("Set up direct access", systemImage: "network", showChevron: true)
                }
                .tint(.primary)
            }
        }
    }

    @ViewBuilder private func headerChip(_ info: NodeInfo) -> some View {
        if isLocal {
            switch NodeLiveState.from(lastOk: live.lastOk, resumed: scenePhase == .active, failing: live.failing) {
            case .connecting: StatusChip("Connecting", color: .ipv64Gray)
            case .paused: StatusChip("Paused", color: .ipv64Gray)
            case .offline: StatusChip("Offline", color: .ipv64Red)
            case .live: StatusChip("Live", color: .ipv64Green)
            }
        } else if info.online == true {
            StatusChip("Online", color: .ipv64Green)
        } else {
            StatusChip("Offline", color: .ipv64Gray)
        }
    }

    @ViewBuilder private var liveLines: some View {
        if let lastOk = live.lastOk {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(verbatim: updatedText(since: lastOk, now: context.date)).font(.footnote).foregroundStyle(.secondary)
            }
        }
        if let lastError = live.status?.link?.lastError?.nonBlank {
            Text("Last error: \(lastError)").font(.footnote).foregroundStyle(Color.ipv64Red)
        }
    }

    // MARK: 2 Stat tiles

    private func statTiles(_ info: NodeInfo) -> some View {
        let outbox = live.status?.link?.outbox ?? info.outbox
        return StatTiles {
            if isLocal {
                StatTile(value: localNode?.uptimeSeconds.map { Formatters.duration(seconds: $0) } ?? "–", label: "Uptime")
            } else {
                StatTile(value: Formatters.ago(info.lastSync) ?? "–", label: "Last sync")
            }
            if !directOnly { StatTile(value: "\(info.checks.count)", label: "Checks") }
            StatTile(value: outbox.map(String.init) ?? "–", label: "Outbox")
            StatTile(value: live.status?.link?.conflicts.map(String.init) ?? info.conflicts.map(String.init) ?? "–",
                     label: "Conflicts", valueColor: conflicts > 0 ? .ipv64Red : nil)
        }
        .padding(.horizontal, 16)
    }

    // MARK: 4 Modules

    @ViewBuilder private func modulesSection(_ info: NodeInfo) -> some View {
        if isLocal, let status = live.status {
            let modules = status.modules ?? []
            Section("Modules (\(modules.count))") {
                ForEach(modules) { module in
                    NodeModuleRow(module: module, busy: isBusy, otherNode: otherNodeId != nil,
                                  onToggle: { toggleModule(module.name, enable: $0) },
                                  onOpen: { router.push(.nodeModule(nodeId: nodeId, module: module.name)) })
                }
            }
        } else {
            Section {
                ForEach(info.modules, id: \.self) { Text(verbatim: $0) }
                if !isLocal { Text("Set up direct access to switch modules.").font(.footnote).foregroundStyle(.secondary) }
            } header: {
                Text("Modules (\(info.modules.count))")
            }
        }
    }

    // MARK: 5 Checks

    private func checksSection(_ info: NodeInfo) -> some View {
        Section {
            if info.checks.isEmpty {
                Text("This node has no checks yet.").foregroundStyle(.secondary)
            } else if canCommand && info.online != true {
                Text("The node is offline. Commands are picked up when it reconnects.").font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(info.checks) { check in
                NodeCheckRow(check: check, canCommand: canCommand, disabled: isBusy || tracking != nil,
                             onOpen: { router.push(.healthcheckDetail(token: check.token)) },
                             onCommand: { ask(NodeCommand.forCheck($0, check)) })
            }
        } header: {
            Text("Checks (\(info.checks.count))")
        }
    }

    // MARK: 8 Details

    private func detailsSection(_ info: NodeInfo) -> some View {
        let rows: [(LocalizedStringKey, String?, Bool)] = [
            ("Node ID", nodeId, true),
            ("Location", localNode?.location?.nonBlank ?? info.location?.nonBlank, false),
            ("Time zone", localNode?.timezone?.nonBlank ?? info.timezone?.nonBlank, false),
            ("Hub", info.hub?.nonBlank, false),
            ("Linked", Formatters.realOrNil(info.linkedAt).map(Formatters.germanTime), false),
            ("Remote management", directOnly ? nil : remoteLabel(info.remote), false),
            ("Started", Formatters.realOrNil(localNode?.startedAt).map(Formatters.germanTime), false),
            ("Database", localNode?.databaseBytes.map { Formatters.bytes(Int64($0)) }, false),
            ("Direct address", access?.url, true),
        ]
        return Section {
            DisclosureGroup("Details") {
                ForEach(rows.indices, id: \.self) { i in
                    if let value = rows[i].1?.nonBlank {
                        LabeledContent { Text(verbatim: value).font(rows[i].2 ? .footnote.monospaced() : .body).textSelection(.enabled) }
                            label: { Text(rows[i].0) }
                    }
                }
            }
        }
    }
}

// MARK: - Rows

private struct NodeModuleRow: View {
    let module: Node64.ModuleStatus
    let busy: Bool
    let otherNode: Bool
    let onToggle: @MainActor @Sendable (Bool) -> Void
    let onOpen: () -> Void

    private var hasScreen: Bool { hasModuleScreen(module.name) && module.enabled == true && !otherNode }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Button(action: onOpen) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: module.name.nonBlank ?? "–")
                            if let version = module.version?.nonBlank { Text(verbatim: version).font(.subheadline).foregroundStyle(.secondary) }
                        }
                        Spacer(minLength: 8)
                        chip
                        if hasScreen { Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary) }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.primary)
                .disabled(!hasScreen)
                Toggle("Enabled", isOn: Binding(get: { module.enabled == true }, set: onToggle))
                    .labelsHidden()
                    .disabled(busy || otherNode)
            }
            if let error = module.lastError?.nonBlank { Text(verbatim: error).font(.footnote).foregroundStyle(Color.ipv64Red) }
        }
    }

    @ViewBuilder private var chip: some View {
        if module.enabled == false { StatusChip("Disabled", color: .ipv64Gray) }
        else if module.running == true { StatusChip("Running", color: .ipv64Green) }
        else { StatusChip("Not running", color: .ipv64Orange) }
    }
}

private struct NodeCheckRow: View {
    let check: HC2Check
    let canCommand: Bool
    let disabled: Bool
    let onOpen: () -> Void
    let onCommand: (HC2CommandName) -> Void

    var body: some View {
        HStack {
            Button(action: onOpen) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: check.name?.nonBlank ?? "–")
                        Text(verbatim: [checkTypeLabel(check.type?.rawValue.lowercased()), check.target?.nonBlank]
                            .compactMap { $0 }.joined(separator: " · "))
                            .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    StatusChip(state: Hc2StateUi.from(check.state?.state?.rawValue, paused: check.paused))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.primary)
            if canCommand {
                Menu {
                    Button("Run check", systemImage: "play") { onCommand(.runCheck) }
                    if check.paused == true {
                        Button("Resume check", systemImage: "play.circle") { onCommand(.resume) }
                    } else {
                        Button("Pause check", systemImage: "pause.circle") { onCommand(.pause) }
                    }
                } label: {
                    Image(systemName: "ellipsis").frame(width: 32, height: 32)
                }
                .accessibilityLabel("Commands for \(check.name?.nonBlank ?? "check")")
                .disabled(disabled)
            }
        }
    }
}

private struct NodeLogsSection: View {
    let lines: [String]
    @State private var showAll = false

    var body: some View {
        Section("Logs") {
            if lines.isEmpty {
                Text("No log lines.").foregroundStyle(.secondary)
            }
            let shown = showAll ? lines : Array(lines.prefix(5))
            ForEach(shown.indices, id: \.self) { NodeLogRow(line: shown[$0]) }
            if lines.count > 5 {
                Button { showAll.toggle() } label: {
                    ListRow(showAll ? "Show fewer logs" : "Show all logs", systemImage: showAll ? "chevron.up" : "chevron.down")
                }
                .tint(.primary)
            }
        }
    }
}

private struct NodeLogRow: View {
    let line: String
    @State private var showRaw = false

    private var entry: NodeLogEntry? { parseNodeLogLine(line) }

    private func color(_ level: String?) -> Color {
        switch level {
        case "DEBUG": .ipv64Gray
        case "WARN", "WARNING": .ipv64Orange
        case "ERROR": .ipv64Red
        default: .primary
        }
    }

    var body: some View {
        if let entry {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if let time = nodeLogClock(entry.time) { Text(verbatim: time).foregroundStyle(.secondary) }
                    if let level = entry.level { Text(verbatim: level).fontWeight(.semibold).foregroundStyle(color(level)) }
                    if let module = entry.module { Text(verbatim: module).foregroundStyle(.secondary) }
                }
                .font(.caption)
                if let msg = entry.msg { Text(verbatim: msg).font(.footnote).foregroundStyle(color(entry.level)) }
                if showRaw { Text(verbatim: line).font(.caption.monospaced()).foregroundStyle(.secondary) }
            }
            .frame(minHeight: 36, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { showRaw.toggle() }
        } else {
            Text(verbatim: line).font(.footnote).foregroundStyle(.secondary)
        }
    }
}
