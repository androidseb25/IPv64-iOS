import Foundation
import IPv64

/// Display data of a node: cloud detail (or a placeholder for direct-only nodes), merged with edits.
struct NodeInfo: Equatable {
    var name: String?
    var location: String?
    var timezone: String?
    var version: String?
    var hub: String?
    var modules: [String] = []
    var remote: String?
    var online: Bool?
    var lastSeen: Date?
    var lastSync: Date?
    var linkedAt: Date?
    var outbox: Int?
    var conflicts: Int?
    var checks: [HC2Check] = []

    init(name: String?) { self.name = name }

    init(_ d: HC2NodeDetail) {
        name = d.name; location = d.location; timezone = d.timezone; version = d.version; hub = d.hub
        modules = d.modules ?? []; remote = d.remoteMgmt?.rawValue; online = d.online
        lastSeen = d.lastSeen; lastSync = d.lastSync; linkedAt = d.linkedAt
        outbox = d.outboxSize; conflicts = d.conflicts; checks = d.checks ?? []
    }

    /// Android `withUpdate`: response values win, missing keep the old; modules only if non-empty.
    func merged(with n: HC2Node) -> NodeInfo {
        var copy = self
        copy.name = n.name ?? name
        copy.location = n.location ?? location
        copy.timezone = n.timezone ?? timezone
        copy.version = n.version ?? version
        copy.hub = n.hub ?? hub
        if let modules = n.modules, !modules.isEmpty { copy.modules = modules }
        copy.remote = n.remoteMgmt?.rawValue ?? remote
        copy.online = n.online ?? online
        copy.lastSeen = n.lastSeen ?? lastSeen
        copy.lastSync = n.lastSync ?? lastSync
        copy.outbox = n.outboxSize ?? outbox
        copy.conflicts = n.conflicts ?? conflicts
        return copy
    }
}

/// Local (direct) live data of a node.
struct NodeLive: Equatable {
    var status: Node64.NodeStatus?
    /// Newest first.
    var logs: [String] = []
    var lastOk: Date?
    var failing = false
    /// Title of the last 401/403 error ("API key rejected"), if that was the last failure.
    var rejected: String?
}

/// A command to send (Android `NodeCommand`); `targetLabel` is the check name used in texts.
struct NodeCommand: Identifiable {
    let id = UUID()
    let name: HC2CommandName
    var args = HC2CommandArguments()
    var targetLabel: String?

    var label: String { commandLabel(name.rawValue) }

    func confirmText(nodeName: String) -> String {
        let target = targetLabel ?? "…"
        switch name {
        case .runCheck: return String(localized: "\(nodeName) is asked to run the check \"\(target)\" now.")
        case .pause: return String(localized: "\(nodeName) is asked to pause the check \"\(target)\". It stays paused until you resume it.")
        case .resume: return String(localized: "\(nodeName) is asked to resume the check \"\(target)\".")
        case .repair: return String(localized: "\(nodeName) is asked to run its repair routine.")
        default:
            let number = args.id.map(String.init) ?? "?"
            let side = args.keep?.rawValue ?? "server"
            return String(localized: "Conflict #\(number) is resolved by keeping the \(side) version. The other version is discarded.")
        }
    }

    /// Command for a check of the node.
    static func forCheck(_ name: HC2CommandName, _ check: HC2Check) -> NodeCommand {
        NodeCommand(name: name, args: HC2CommandArguments(token: check.token),
                    targetLabel: check.name?.nonBlank ?? "…" + String(check.token.suffix(4)))
    }
}
