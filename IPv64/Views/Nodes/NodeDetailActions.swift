import SwiftUI
import IPv64

// Loading, live tick, modules, commands, forget and unlink of the node detail.
extension NodeDetailView {
    /// The first live request starts at once, next to the cloud request; the 5 s tick follows.
    func start() async {
        access = nodes.access(for: nodeId)
        async let live: Void = tick(force: true)
        await loadCloud()
        await live
    }

    func loadCloud() async {
        let api = session.api
        isLoading = true
        defer { isLoading = false }
        do {
            let detail = try await ipv64Retrying { try await api.hc2.nodes.get(nodeId) }
            info = NodeInfo(detail)
            directOnly = false
            planReason = nil
            loadFailed = false
        } catch is CancellationError {
        } catch {
            let status = (error as? IPv64Error)?.statusCode
            if isLocal, status == 404 || status == 403 {
                // Not linked to the account (or nodes not in the plan): a directly connected node only.
                directOnly = true
                if info == nil { info = NodeInfo(name: LocalNodeStore.name(nodeId)) }
                loadFailed = false
            } else if status == 403 {
                if case .api(let problem)? = error as? IPv64Error, let detail = problem.detail.nonBlank {
                    planReason = detail
                } else {
                    planReason = String(localized: "This feature is not available on your plan.")
                }
            } else {
                if info == nil { loadFailed = true }
                self.error = ErrorText(error)
            }
        }
    }

    /// Pull to refresh: cloud, live data and the open command history.
    func refresh() async {
        await loadCloud()
        await tick(force: true)
        if historyOpen && tracking == nil { await loadCommands() }
    }

    /// Alerts wait until the sheet is gone: a resolve command gets confirmed, the unlink result is shown.
    func sheetClosed() {
        if let command = pendingCommand {
            pendingCommand = nil
            confirmCommand = command
        }
        if let pendingError {
            self.pendingError = nil
            error = pendingError
        }
        if let pendingUnlink {
            self.pendingUnlink = nil
            unlinkText = pendingUnlink
        }
    }

    /// After the connection sheet: a changed direct access is read again.
    func reloadAccess() {
        let stored = nodes.access(for: nodeId)
        if stored != access {
            access = stored
            live = NodeLive()
        }
    }

    // MARK: Live

    /// Every 5 s (first at once) while the screen is visible and the app active.
    func tickLoop() async {
        guard isLocal, scenePhase == .active else { return }
        // The first request comes from start() (or right here after returning to the app).
        if live.lastOk != nil { await tick(force: false) }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(5))
            if Task.isCancelled { return }
            await tick(force: false)
        }
    }

    /// Silent live refresh: `status()` then `logs(100)`; skipped while an action or another refresh runs.
    func tick(force: Bool) async {
        guard let config = access, !isTicking, force || !busy,
              let client = NodeClientFactory.client(for: config) else { return }
        isTicking = true
        defer { isTicking = false }
        do {
            // Status first: the screen shows the node as connected without waiting for the (slower) logs.
            let status = try await client.node.status()
            guard access == config else { return }
            if let name = status.node?.name?.nonBlank, name != LocalNodeStore.name(nodeId) { LocalNodeStore.setName(nodeId, name) }
            if let modules = status.modules { LocalNodeStore.saveModules(nodeId, modules: modules) }
            nodes.refresh()
            live = NodeLive(status: status, logs: live.logs, lastOk: .now, failing: false, rejected: nil)
            if let logs = try? await client.node.logs(lines: 100).lines, access == config {
                live.logs = logs.reversed().map(NodesLogic.logText)
            }
        } catch is CancellationError {
        } catch {
            guard access == config else { return }
            live.failing = true
            live.rejected = NodesLogic.isAuthRejection(error) ? ErrorText.node(error).title : nil
        }
    }

    // MARK: Modules

    func toggleModule(_ name: String, enable: Bool) {
        if enable {
            Task { await setModule(name, enable: true) }
        } else {
            confirmDisable = name
        }
    }

    func setModule(_ name: String, enable: Bool) async {
        guard let config = access, let client = NodeClientFactory.client(for: config) else { return }
        busy = true
        defer { busy = false }
        do {
            if enable {
                _ = try await client.node.modules.enable(name)
            } else {
                _ = try await client.node.modules.disable(name)
            }
            let status = try await client.node.status()
            guard access == config else { return }
            if let modules = status.modules { LocalNodeStore.saveModules(nodeId, modules: modules) }
            live.status = status
            nodes.refresh()
            await nodes.refreshModules()
        } catch is CancellationError {
        } catch {
            self.error = ErrorText.node(error)
        }
    }

    // MARK: Commands

    func send(_ command: NodeCommand) async {
        let api = session.api
        busy = true
        defer { busy = false }
        do {
            let args = command.args == HC2CommandArguments() ? nil : command.args
            let sent = try await ipv64Retrying { try await api.hc2.nodes.sendCommand(nodeId, name: command.name, arguments: args) }
            historyOpen = true
            historyLoaded = true
            commands.insert(sent, at: 0)
            tracking = sent.commandID
        } catch is CancellationError {
        } catch {
            self.error = ErrorText(error)
        }
    }

    func loadCommands() async {
        let api = session.api
        historyLoading = true
        defer { historyLoading = false }
        do {
            commands = try await ipv64Retrying { try await api.hc2.nodes.commands(nodeId, limit: 20) }
            historyLoaded = true
        } catch is CancellationError {
        } catch {
            self.error = ErrorText(error)
        }
    }

    /// Polls every 3 s for up to 60 s until the sent command is done; the screen stays usable meanwhile.
    func trackCommand() async {
        guard let id = tracking else { return }
        let api = session.api
        var finished: HC2Command?
        do {
            for _ in 0..<20 {
                try await Task.sleep(for: .seconds(3))
                let list = try await ipv64Retrying { try await api.hc2.nodes.commands(nodeId, limit: 20) }
                commands = list
                finished = list.first { $0.commandID == id && $0.doneAt != nil }
                if finished != nil { break }
            }
        } catch is CancellationError {
            return
        } catch {
            self.error = ErrorText(error)
            tracking = nil
            return
        }
        if let finished {
            if finished.ok == false {
                error = ErrorText(title: String(localized: "Command failed"),
                                  message: HcFormat.commandOutput(finished.output) ?? String(localized: "The node reported an error."))
            }
        } else {
            error = ErrorText(title: String(localized: "Command still pending"),
                              message: String(localized: "The node has not reported back yet. It runs the command as soon as it syncs. Open the command history later to see the result."))
        }
        await loadCloud()
        // Last: clearing `tracking` cancels this task.
        tracking = nil
    }

    // MARK: Forget / unlink

    func forget() {
        LocalNodeStore.remove(nodeId)
        nodes.refresh()
        onChanged()
        if directOnly {
            dismiss()
        } else {
            access = nil
            live = NodeLive()
        }
    }

    func handleUnlink(_ result: HC2NodeUnlinkResult) {
        if result.unlinked == false {
            pendingError = ErrorText(title: String(localized: "Node not unlinked"),
                              message: String(localized: "The server did not unlink the node. Please try again."))
            return
        }
        tracking = nil
        // The stored direct access stays; live updates stop.
        access = nil
        live = NodeLive()
        onChanged()
        pendingUnlink = NodesLogic.unlinkSummary(kept: result.checksKeptOnline ?? 0, deleted: result.checksDeleted ?? 0)
    }
}
