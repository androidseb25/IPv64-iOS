import SwiftUI
import IPv64

// List sections of the node detail; empty sections are left out.
extension NodeDetailView {
    @ViewBuilder func sections(_ info: NodeInfo) -> some View {
        headerSection(info)
        statusSection(info)
        modulesSection(info)
        if !directOnly && !info.checks.isEmpty { checksSection(info) }
        if isLocal, live.status != nil, !live.logs.isEmpty { NodeLogsSection(lines: live.logs) }
        if !directOnly { commandsSection(info) }
        detailsSection(info)
    }

    // MARK: Header

    private func headerSection(_ info: NodeInfo) -> some View {
        let version = (localNode?.version?.nonBlank ?? info.version?.nonBlank).map { "v" + $0 }
        let source: String? = if let config = access {
            String(localized: "Direct \(LocalNodeURL.host(of: config.url) ?? config.url)")
        } else {
            [String(localized: "Cloud"),
             HcFormat.real(info.lastSeen).map { String(localized: "seen \($0.formatted(.relative(presentation: .named)))") }]
                .compactMap { $0 }.joined(separator: " · ")
        }
        let subtitle = [version, source].compactMap { $0 }.joined(separator: " · ")
        return Section {
            if isLocal && live.failing {
                Text(live.rejected ?? String(localized: "Connection lost — retrying…")).foregroundStyle(.red)
            }
            if let other = otherNodeId {
                Text("This address belongs to another node (\(other)). Forget the direct connection and connect again.")
                    .foregroundStyle(.red)
            }
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName).font(.headline)
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                headerTag(info)
            }
            .accessibilityElement(children: .combine)
            if isLocal { liveLines }
        }
    }

    @ViewBuilder private func headerTag(_ info: NodeInfo) -> some View {
        if isLocal {
            switch NodesLogic.LiveState.from(lastOk: live.lastOk, active: scenePhase == .active, failing: live.failing) {
            case .connecting: HealthcheckTag(text: "Connecting", color: .gray)
            case .paused: HealthcheckTag(text: "Paused", color: .gray)
            case .offline: HealthcheckTag(text: "Offline", color: .red)
            case .live: HealthcheckTag(text: "Live", color: .green)
            }
        } else if info.online == true {
            HealthcheckTag(text: "Online", color: .green)
        } else {
            HealthcheckTag(text: "Offline", color: .gray)
        }
    }

    @ViewBuilder private var liveLines: some View {
        if let lastOk = live.lastOk {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(NodesLogic.updatedText(since: lastOk, now: context.date)).font(.footnote).foregroundStyle(.secondary)
            }
        }
        if let lastError = live.status?.link?.lastError?.nonBlank {
            Text("Last error: \(lastError)").font(.footnote).foregroundStyle(.red)
        }
    }

    // MARK: Status (prominent value + rows, like the healthcheck statistics)

    private func statusSection(_ info: NodeInfo) -> some View {
        let outbox = live.status?.link?.outbox ?? info.outbox
        let conflictCount = live.status?.link?.conflicts ?? info.conflicts
        let main: (value: String, label: LocalizedStringKey) = isLocal
            ? (localNode?.uptimeSeconds.map { HcFormat.duration(seconds: $0) } ?? "–", "Uptime")
            : (HcFormat.real(info.lastSync).map { $0.formatted(.relative(presentation: .named)) } ?? "–", "Last sync")
        return Section("Status") {
            VStack(alignment: .leading, spacing: 2) {
                Text(main.value).font(.system(size: 40, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.5)
                Text(main.label).font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            if !directOnly { LabeledContent("Checks", value: info.checks.count.formatted()) }
            if let outbox { LabeledContent("Outbox", value: outbox.formatted()) }
            if let conflictCount {
                LabeledContent("Conflicts") {
                    Text(conflictCount.formatted()).foregroundStyle(conflictCount > 0 ? Color.red : Color.secondary)
                }
            }
        }
    }

    // MARK: Modules

    @ViewBuilder private func modulesSection(_ info: NodeInfo) -> some View {
        if isLocal, let modules = live.status?.modules, !modules.isEmpty {
            Section("Modules (\(modules.count))") {
                ForEach(modules) { module in
                    let screen = NodeModuleView.hasScreen(module.name) && module.enabled == true && otherNodeId == nil
                    NodeModuleRow(module: module, disabled: busy || otherNodeId != nil,
                                  onOpen: screen ? { moduleScreen = module.name } : nil) { toggleModule(module.name, enable: $0) }
                }
            }
        } else if !info.modules.isEmpty {
            Section {
                ForEach(info.modules, id: \.self) { Text($0) }
            } header: {
                Text("Modules (\(info.modules.count))")
            } footer: {
                if !isLocal { Text("Set up direct access to switch modules.") }
            }
        }
    }

    // MARK: Checks

    private func checksSection(_ info: NodeInfo) -> some View {
        Section {
            ForEach(info.checks) { check in
                NavigationLink(value: HealthcheckRoute(token: check.token)) { HealthcheckItemView(check: check) }
                    .swipeActions {
                        if canCommand {
                            Group {
                                Button("Run check", systemImage: "arrow.clockwise") { confirmCommand = .forCheck(.runCheck, check) }
                                    .tint(.blue)
                                if check.paused == true {
                                    Button("Resume check", systemImage: "play") { confirmCommand = .forCheck(.resume, check) }
                                        .tint(.green)
                                } else {
                                    Button("Pause check", systemImage: "pause") { confirmCommand = .forCheck(.pause, check) }
                                        .tint(.teal)
                                }
                            }
                            .labelStyle(.iconOnly)
                            .disabled(tracking != nil)
                        }
                    }
            }
        } header: {
            Text("Checks (\(info.checks.count))")
        } footer: {
            if canCommand && info.online != true {
                Text("The node is offline. Commands are picked up when it reconnects.")
            }
        }
    }

    // MARK: Commands

    @ViewBuilder private func commandsSection(_ info: NodeInfo) -> some View {
        if tracking != nil {
            Section {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Waiting for the node to run the command…").foregroundStyle(.secondary)
                }
            }
        }
        HcCollapsibleSection(title: "Command history", isExpanded: $historyOpen) {
            if historyLoading && !historyLoaded {
                ProgressView().frame(maxWidth: .infinity)
            } else if commands.isEmpty {
                Text("No commands sent yet.").foregroundStyle(.secondary)
            }
            ForEach(commands) { command in
                NodeCommandRow(command: command) { token in
                    info.checks.first { $0.token == token }?.name?.nonBlank ?? String(localized: "Unknown check …\(String(token.suffix(4)))")
                }
            }
        }
    }

    // MARK: Details

    private func detailsSection(_ info: NodeInfo) -> some View {
        HcCollapsibleSection(title: "Details", isExpanded: $detailsOpen) {
            NodeInfoRow("Node ID", nodeId, copyable: true)
            NodeInfoRow("Location", localNode?.location?.nonBlank ?? info.location)
            NodeInfoRow("Time zone", localNode?.timezone?.nonBlank ?? info.timezone)
            NodeInfoRow("Hub", info.hub)
            NodeInfoRow("Linked", HcFormat.time(info.linkedAt))
            NodeInfoRow("Remote management", directOnly ? nil : NodesLogic.remoteLabel(info.remote))
            NodeInfoRow("Started", HcFormat.time(localNode?.startedAt))
            NodeInfoRow("Database", localNode?.databaseBytes.map { Int64($0).formatted(.byteCount(style: .file)) })
            NodeInfoRow("Direct address", access?.url, copyable: true)
        }
    }
}

// MARK: - Rows

/// `LabeledContent` that disappears for blank values; copyable ones are monospaced with a Copy menu.
private struct NodeInfoRow: View {
    let label: LocalizedStringKey
    let value: String?
    var copyable = false

    init(_ label: LocalizedStringKey, _ value: String?, copyable: Bool = false) {
        self.label = label
        self.value = value?.nonBlank
        self.copyable = copyable
    }

    var body: some View {
        if let value {
            LabeledContent(label) {
                Text(value).font(copyable ? .footnote.monospaced() : .body).textSelection(.enabled)
            }
            .contextMenu {
                if copyable { Button("Copy", systemImage: "doc.on.doc") { Clipboard.copy(value) } }
            }
        }
    }
}

private struct NodeModuleRow: View {
    let module: Node64.ModuleStatus
    let disabled: Bool
    /// `nil` = the module has no screen here.
    let onOpen: (() -> Void)?
    let onToggle: (Bool) -> Void

    private var state: (text: LocalizedStringKey, color: Color) {
        if module.enabled == false { return ("Disabled", .secondary) }
        return module.running == true ? ("Running", .green) : ("Not running", .orange)
    }

    private var label: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(module.name.nonBlank ?? "–")
            HStack(spacing: 4) {
                if let version = module.version?.nonBlank { Text(verbatim: "v\(version) ·").foregroundStyle(.secondary) }
                Text(state.text).foregroundStyle(state.color)
            }
            .font(.subheadline)
            if let error = module.lastError?.nonBlank { Text(error).font(.footnote).foregroundStyle(.red) }
        }
    }

    private var toggle: Binding<Bool> { Binding(get: { module.enabled == true }, set: onToggle) }

    var body: some View {
        if let onOpen {
            // Borderless button and switch side by side: the row opens the module, the switch toggles it.
            HStack(spacing: 12) {
                Button(action: onOpen) {
                    HStack {
                        label
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .tint(.primary)
                Toggle(module.name, isOn: toggle)
                    .labelsHidden()
                    .disabled(disabled || module.name.nonBlank == nil)
            }
        } else {
            Toggle(isOn: toggle) { label }
                .disabled(disabled || module.name.nonBlank == nil)
        }
    }
}

private struct NodeCommandRow: View {
    let command: HC2Command
    let checkName: (String) -> String

    private var subtitle: String? {
        let times = [
            HcFormat.real(command.createdAt).map { String(localized: "sent \($0.formatted(.relative(presentation: .named)))") },
            HcFormat.time(command.doneAt).map { String(localized: "finished \($0)") },
        ].compactMap { $0 }.joined(separator: " · ")
        return [NodesLogic.commandArgsText(command.args, checkName: checkName), times.nonBlank]
            .compactMap { $0 }.joined(separator: "\n").nonBlank
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(NodesLogic.commandLabel(command.name))
                    if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if command.doneAt == nil {
                    HealthcheckTag(text: "Pending", color: .orange)
                } else if command.ok == true {
                    HealthcheckTag(text: "OK", color: .green)
                } else if command.ok == false {
                    HealthcheckTag(text: "Failed", color: .red)
                } else {
                    HealthcheckTag(text: "Done", color: .gray)
                }
            }
            if let output = HcFormat.commandOutput(command.output) {
                Text(output).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(6)
            }
        }
    }
}

private struct NodeLogsSection: View {
    let lines: [String]
    @State private var showAll = false

    var body: some View {
        Section("Logs") {
            let shown = showAll ? lines : Array(lines.prefix(5))
            ForEach(shown.indices, id: \.self) { NodeLogRow(line: shown[$0]) }
            if lines.count > 5 {
                Button {
                    withAnimation { showAll.toggle() }
                } label: {
                    Label(showAll ? "Show fewer logs" : "Show all logs", systemImage: showAll ? "chevron.up" : "chevron.down")
                }
                .tint(.primary)
            }
        }
    }
}

/// Parsed logfmt line (time, level, module, message); a tap shows the raw line.
private struct NodeLogRow: View {
    let line: String
    @State private var showRaw = false

    private var entry: NodesLogic.LogEntry? { NodesLogic.parseLogLine(line) }

    private func color(_ level: String?) -> Color {
        switch level {
        case "DEBUG": .secondary
        case "WARN", "WARNING": .orange
        case "ERROR": .red
        default: .primary
        }
    }

    var body: some View {
        if let entry {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if let time = NodesLogic.logClock(entry.time) { Text(time).foregroundStyle(.secondary) }
                    if let level = entry.level { Text(level).fontWeight(.semibold).foregroundStyle(color(level)) }
                    if let module = entry.module { Text(module).foregroundStyle(.secondary) }
                }
                .font(.caption)
                if let msg = entry.msg { Text(msg).font(.footnote).foregroundStyle(color(entry.level)) }
                if showRaw { Text(line).font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled) }
            }
            .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { withAnimation { showRaw.toggle() } }
        } else {
            Text(line).font(.footnote.monospaced()).foregroundStyle(.secondary)
        }
    }
}
