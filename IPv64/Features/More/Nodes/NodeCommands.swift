import SwiftUI
import IPv64

// Commands and command history (spec 04 §4: "Commands", "track", section 7).
extension NodeDetailView {
    /// Asks for confirmation, then sends.
    func ask(_ command: NodeCommand) {
        let name = info?.name?.nonBlank ?? displayName.nonBlank ?? String(localized: "The node")
        confirm = ConfirmRequest(
            title: String(localized: "\(command.label)?"), message: command.confirmText(nodeName: name),
            confirmLabel: String(localized: "Send"), destructive: command.name == .resolveConflict) { Task { await send(command) } }
    }

    /// Resolve-conflict sheet closed with a command: confirm it.
    func confirmPendingCommand() {
        guard let command = pendingCommand else { return }
        pendingCommand = nil
        ask(command)
    }

    private func send(_ command: NodeCommand) async {
        spinner = "Sending command..."
        defer { spinner = nil }
        do {
            let args = command.args == HC2CommandArguments() ? nil : command.args
            let sent = try await ipv64Retrying { try await session.api.hc2.nodes.sendCommand(nodeId, name: command.name, arguments: args) }
            historyOpen = true
            historyLoaded = true
            commands.insert(sent, at: 0)
            tracking = sent.commandID
        } catch is CancellationError {
            return
        } catch {
            self.error = ErrorText(error)
        }
    }

    func loadCommands() async {
        historyLoading = true
        defer { historyLoading = false }
        do {
            commands = try await ipv64Retrying { try await session.api.hc2.nodes.commands(nodeId, limit: 20) }
            historyLoaded = true
        } catch is CancellationError {
            return
        } catch {
            self.error = ErrorText(error)
        }
    }

    /// Polls every 3 s up to 60 s until the sent command is done; the screen stays usable meanwhile.
    func trackCommand() async {
        guard let id = tracking else { return }
        do {
            let finished = try await pollUntil(
                interval: .seconds(3), max: .seconds(60),
                onEach: { commands = $0 },
                fetch: { try await session.api.hc2.nodes.commands(nodeId, limit: 20) },
                done: { $0.contains { $0.commandID == id && $0.doneAt != nil } })
            if let command = finished?.first(where: { $0.commandID == id }) {
                if command.ok == false {
                    message = ErrorText(title: String(localized: "Command failed"),
                                        message: jsonOutputText(command.output) ?? String(localized: "The node reported an error."))
                }
            } else {
                message = ErrorText(title: String(localized: "Command still pending"),
                                    message: String(localized: "The node has not reported back yet. It runs the command as soon as it syncs. Open the command history later to see the result."))
            }
            await loadCloud()
            tracking = nil
        } catch is CancellationError {
            return
        } catch {
            self.error = ErrorText(error)
            tracking = nil
        }
    }

    // MARK: History section

    func historySection(_ info: NodeInfo) -> some View {
        Section {
            DisclosureGroup(isExpanded: $historyOpen) {
                if commands.isEmpty && historyLoaded { Text("No commands sent yet.").foregroundStyle(.secondary) }
                ForEach(commands) { command in
                    NodeCommandRow(command: command, checkName: { token in
                        info.checks.first { $0.token == token }?.name?.nonBlank ?? String(localized: "Unknown check …\(token.suffix(4))")
                    })
                }
            } label: {
                HStack {
                    Text("Command history")
                    Spacer()
                    if historyLoading {
                        ProgressView()
                    } else if historyOpen {
                        Button("Reload commands", systemImage: "arrow.clockwise") { Task { await loadCommands() } }
                            .labelStyle(.iconOnly).buttonStyle(.borderless)
                    }
                }
            }
        }
    }
}

private struct NodeCommandRow: View {
    let command: HC2Command
    let checkName: (String) -> String

    private var subtitle: String? {
        let times = [
            Formatters.realOrNil(command.createdAt).map { String(localized: "sent \(Formatters.relative($0))") },
            Formatters.realOrNil(command.doneAt).map { String(localized: "finished \(Formatters.germanTime($0))") },
        ].compactMap { $0 }.joined(separator: " · ")
        return [commandArgsText(command.args, checkName: checkName), times.nonBlank].compactMap { $0 }.joined(separator: "\n").nonBlank
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: commandLabel(command.name))
                    if let subtitle { Text(verbatim: subtitle).font(.subheadline).foregroundStyle(.secondary) }
                }
                Spacer(minLength: 8)
                if command.doneAt == nil { StatusChip("Pending", color: .ipv64Orange) }
                else if command.ok == true { StatusChip("OK", color: .ipv64Green) }
                else if command.ok == false { StatusChip("Failed", color: .ipv64Red) }
                else { StatusChip("Done", color: .ipv64Gray) }
            }
            if let output = jsonOutputText(command.output) {
                Text(verbatim: output).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(6)
            }
        }
    }
}
