import SwiftUI
import IPv64

/// Header (name, server, status, pending work) and the "Details" rows.
struct CdnHeaderSections: View {
    let detail: CDNDomainDetail

    var body: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: detail.displayName).font(.headline)
                    let server = [detail.server?.name, detail.server?.hostname].compactMap { $0?.nonBlank }.joined(separator: " · ")
                    if !server.isEmpty { Text(verbatim: server).font(.subheadline).foregroundStyle(.secondary) }
                }
                Spacer()
                if detail.active == true { StatusChip("Active", color: .ipv64Green) } else { StatusChip("Inactive", color: .ipv64Gray) }
            }
            if detail.isBusy {
                ProgressView().progressViewStyle(.linear)
                let tasks = Array(NSOrderedSet(array: (detail.pending ?? []).map(\.label))) as? [String] ?? []
                Text(verbatim: (tasks.isEmpty ? String(localized: "Applying changes") : tasks.joined(separator: ", "))
                     + String(localized: ". This usually takes a few seconds."))
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        Section("Details") {
            if let v4 = detail.server?.ipv4 { InfoLine("Server IPv4", v4, monospaced: true) }
            if let v6 = detail.server?.ipv6 { InfoLine("Server IPv6", v6, monospaced: true) }
            InfoLine("Records via CDN", detail.dnsRecordsEnabled == true ? String(localized: "Yes") : String(localized: "No"))
            InfoLine("Traffic", detail.trafficText)
            if let created = detail.createdAt { InfoLine("Added", Formatters.germanTime(created)) }
        }
    }
}

/// Label/value row; the value can be selected and copied.
struct InfoLine: View {
    let label: LocalizedStringKey
    let value: String
    var monospaced = false

    init(_ label: LocalizedStringKey, _ value: String, monospaced: Bool = false) {
        self.label = label
        self.value = value
        self.monospaced = monospaced
    }

    var body: some View {
        LabeledContent(label) {
            Text(verbatim: value).font(monospaced ? .body.monospaced() : .body).textSelection(.enabled)
        }
    }
}

/// Reverse proxy status, settings summary and tiles.
struct CdnProxySection: View {
    let detail: CDNDomainDetail
    let enabled: Bool
    let lockTasks: Bool
    let toggleProxy: () -> Void
    let renew: () -> Void
    let settings: () -> Void

    var body: some View {
        let proxy = detail.proxy
        let state = proxy?.state
        let on = state == .on
        let canEnable = detail.dnsRecordsEnabled == true
        Section {
            LabeledContent("Status") { StatusChip(verbatim: state.label, color: state.color) }
            InfoLine("Frontend", proxy?.frontend?.label ?? String(localized: "Unknown"))
            if let backend = proxy?.backend {
                InfoLine("Origin server", "\(backend.scheme?.label ?? String(localized: "Unknown")) · port \(backend.port.map(String.init) ?? "–")")
            }
            InfoLine("WebSocket", proxy?.websocket == true ? String(localized: "On") : String(localized: "Off"))
            InfoLine("Certificate", proxy?.certificate?.label ?? String(localized: "Unknown"))
            let cache = proxy?.caching
            InfoLine("Cache", cache?.enabled == true
                     ? "On · \(cache?.timeMinutes.map(String.init) ?? "–") min · \(cache?.sizeMB.map(String.init) ?? "–") MB" : String(localized: "Off"))
            let acl = proxy?.accessList
            InfoLine("Access list", acl?.enabled == true ? "On · \(acl?.mode?.label ?? String(localized: "Unknown"))" : String(localized: "Off"))
            ActionTileRow {
                if on {
                    ActionTile("Switch off", systemImage: "icloud.slash", action: toggleProxy).disabled(!enabled || lockTasks)
                } else {
                    ActionTile("Switch on", systemImage: "icloud", action: toggleProxy)
                        .disabled(!enabled || lockTasks || !canEnable || state == .disabling)
                }
                ActionTile("Settings", systemImage: "slider.horizontal.3", action: settings).disabled(!enabled)
                if on && proxy?.frontend != .http {
                    ActionTile("Renew certificate", systemImage: "arrow.triangle.2.circlepath", action: renew)
                        .disabled(!enabled || lockTasks)
                }
            }
            .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
        } header: {
            Text("Reverse proxy")
        } footer: {
            if !on && state != .disabling && !canEnable {
                Text("Enable the CDN for at least one record before you switch the proxy on.")
            }
        }
    }
}

/// Port mapper status and the mappings.
struct CdnPortmapperSection: View {
    let detail: CDNDomainDetail
    let enabled: Bool
    let lockTasks: Bool
    let toggle: () -> Void
    let addMapping: () -> Void
    let deleteMapping: (CDNMapping) -> Void

    var body: some View {
        let state = detail.portmapper?.state
        let on = state == .on
        let canEnable = detail.dnsRecordsEnabled == true
        Section {
            VStack(alignment: .leading, spacing: 4) {
                LabeledContent("Status") { StatusChip(verbatim: state.label, color: state.color) }
                Text("Forwards public ports of the CDN server (TCP/UDP) to ports on your server.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(detail.mappings ?? []) { mapping in
                MappingRow(mapping: mapping, enabled: enabled) { deleteMapping(mapping) }
            }
            ActionTileRow {
                if on {
                    ActionTile("Switch off", systemImage: "icloud.slash", action: toggle).disabled(!enabled || lockTasks)
                } else {
                    ActionTile("Switch on", systemImage: "arrow.triangle.branch", action: toggle)
                        .disabled(!enabled || lockTasks || !canEnable || state == .disabling || state == .suspendedTrafficLimit)
                }
                ActionTile("Mapping", systemImage: "plus", action: addMapping).disabled(!enabled)
            }
            .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
        } header: {
            Text("Port mapper")
        } footer: {
            if !on && !canEnable { Text("Enable the CDN for at least one record before you switch the port mapper on.") }
        }
    }
}

private struct MappingRow: View {
    let mapping: CDNMapping
    let enabled: Bool
    let delete: () -> Void

    var body: some View {
        let line = "Public port \(mapping.listenPort.map(String.init) ?? "–") → port \(mapping.targetPort.map(String.init) ?? "–") (\(mapping.transport?.label ?? "TCP"))"
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: mapping.name?.nonBlank ?? String(localized: "Port mapping"))
                Text(verbatim: line).font(.subheadline).foregroundStyle(.secondary)
                if let fqdn = mapping.fqdn?.nonBlank { Text(verbatim: fqdn).font(.subheadline).foregroundStyle(.secondary) }
            }
            Spacer()
            Button("Delete port mapping", systemImage: "trash", role: .destructive, action: delete)
                .labelStyle(.iconOnly).buttonStyle(.borderless).disabled(!enabled)
        }
    }
}
