import SwiftUI
import IPv64

// Loading, live tick, module switch, forget, unlink (spec 04 §4 "State & timers").
extension NodeDetailView {
    func loadCloud() async {
        do {
            let detail = try await ipv64Retrying { try await session.api.hc2.nodes.get(nodeId) }
            info = NodeInfo(detail)
            directOnly = false
            planReason = nil
            loadFailed = false
        } catch is CancellationError {
            return
        } catch {
            let apiError = error as? IPv64Error
            if isLocal, apiError?.isNotFound == true || apiError?.isPlanRestricted == true {
                directOnly = true
                if info == nil { info = NodeInfo(name: storedName) }
                loadFailed = false
            } else if apiError?.isPlanRestricted == true {
                planReason = apiError?.planRestrictionText
            } else {
                if info == nil { loadFailed = true }
                self.error = ErrorText(error)
            }
        }
    }

    /// Pull to refresh: cloud + local (+ open history).
    func refresh() async {
        await loadCloud()
        await tick(force: true)
        if historyOpen && tracking == nil { await loadCommands() }
    }

    /// Every 5 s (first immediately) while the screen is visible and the app active.
    func tickLoop() async {
        guard isLocal, scenePhase == .active else { return }
        while !Task.isCancelled {
            await tick(force: false)
            try? await Task.sleep(for: .seconds(5))
        }
    }

    /// Silent live refresh: `status()` then `logs(100)`; skipped while a user request or another refresh runs.
    func tick(force: Bool) async {
        guard let config = access, !isRefreshing, force || !isBusy,
              let client = NodeClientFactory.client(for: config) else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let status = try await client.node.status()
            let logs = try await client.node.logs(lines: 100).lines ?? []
            guard access == config else { return }
            if let name = status.node?.name?.nonBlank, name != LocalNodeStore.name(nodeId) { LocalNodeStore.setName(nodeId, name) }
            if let modules = status.modules { LocalNodeStore.saveModules(nodeId, modules: modules) }
            nodes.refresh()
            live = NodeLive(status: status, logs: logs.reversed().map(nodeLogText), lastOk: .now, failing: false, rejected: nil)
        } catch is CancellationError {
            return
        } catch {
            guard access == config else { return }
            live.failing = true
            live.rejected = isNodeAuthRejection(error) ? ErrorText.node(error).title : nil
        }
    }

    // MARK: Modules

    func toggleModule(_ name: String, enable: Bool) {
        if enable {
            Task { await setModule(name, enable: true) }
        } else {
            confirm = ConfirmRequest(
                title: String(localized: "Disable \(name)?"),
                message: String(localized: "Disable \(name)? Services of this module stop on the node, e.g. DNS for your network."),
                confirmLabel: String(localized: "Disable"), destructive: true) { Task { await setModule(name, enable: false) } }
        }
    }

    private func setModule(_ name: String, enable: Bool) async {
        guard let config = access, let client = NodeClientFactory.client(for: config) else { return }
        spinner = "Loading..."
        defer { spinner = nil }
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
            return
        } catch {
            message = ErrorText.node(error)
        }
    }

    // MARK: Forget / unlink

    func askForget() {
        confirm = ConfirmRequest(
            title: String(localized: "Forget direct connection?"),
            message: String(localized: "The address and API key are removed from this device. The node itself is not changed."),
            confirmLabel: String(localized: "Forget"), destructive: true) { Task { await forget() } }
    }

    private func forget() async {
        LocalNodeStore.remove(nodeId)
        nodes.refresh()
        await nodes.refreshModules()
        if directOnly {
            router.reload()
            router.pop()
        } else {
            access = nil
            live = NodeLive()
        }
    }

    func handleUnlink(_ result: HC2NodeUnlinkResult) {
        sheet = nil
        if result.unlinked == false {
            message = ErrorText(title: String(localized: "Node not unlinked"),
                                message: String(localized: "The server did not unlink the node. Please try again."))
            return
        }
        tracking = nil
        access = nil
        live = NodeLive()
        popAfterMessage = true
        message = ErrorText(title: String(localized: "Node unlinked"),
                            message: unlinkSummary(kept: result.checksKeptOnline ?? 0, deleted: result.checksDeleted ?? 0))
    }
}
