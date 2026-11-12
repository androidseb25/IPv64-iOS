import Foundation
import AppIntents
import WidgetKit
import SwiftUI
import IPv64

// MARK: - Nodes of the widget account

/// A directly connected node with DNS64 (LocalNodeStore id + display name).
struct DNS64NodeEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "DNS64 node"
    static let defaultQuery = DNS64NodeQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation { .init(title: "\(name)") }
}

struct DNS64NodeQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [DNS64NodeEntity] {
        DNS64Nodes.all().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [DNS64NodeEntity] { DNS64Nodes.all() }

    func defaultResult() async -> DNS64NodeEntity? { DNS64Nodes.all().first }
}

/// Node access for the widget. Only nodes stored for the widget account (Keychain `API_KEY_WIDGET`) are used;
/// keys come from the shared Keychain via `LocalNodeStore` and go only to the node, through the app's hardened `NodeTransport`.
nonisolated enum DNS64Nodes {
    private struct Account: Decodable {
        let uuid: String?
        let ApiKey: String
    }

    /// `LocalNodeStore` owner of the widget account (`User.uuid` of the stored account with the widget key).
    static func owner() -> String? {
        guard let key = try? SecureStore.readString("API_KEY_WIDGET"), !key.isEmpty,
              let data = try? SecureStore.read("USER_ACCOUNTS"),
              let accounts = try? JSONDecoder().decode([Account].self, from: data) else { return nil }
        return accounts.first { $0.ApiKey == key }?.uuid
    }

    /// Nodes of the widget account whose last known status had DNS64 enabled (same set as the app's DNS64 tab).
    static func all() -> [DNS64NodeEntity] {
        guard let owner = owner() else { return [] }
        return LocalNodeStore.list(owner: owner).filter(LocalNodeStore.dnsActive).map {
            DNS64NodeEntity(id: $0, name: LocalNodeStore.name($0)?.trimmingCharacters(in: .whitespaces).nilIfEmpty
                            ?? "Node …" + String($0.suffix(4)))
        }
    }

    /// The configured node, or the first one; `nil` when the account has no DNS64 node.
    static func resolve(_ id: String?) -> (node: DNS64NodeEntity, client: Node64)? {
        guard let owner = owner() else { return nil }
        let nodes = all()
        guard let node = nodes.first(where: { $0.id == id }) ?? nodes.first,
              let access = LocalNodeStore.get(node.id, owner: owner),
              let client = NodeClientFactory.client(for: access) else { return nil }
        return (node, client)
    }

    static func client(_ id: String?) throws -> Node64 {
        guard let client = resolve(id)?.client else { throw DNS64IntentError.noNode }
        return client
    }

    /// Widget and Control show the new state right away.
    static func reload() {
        WidgetCenter.shared.reloadTimelines(ofKind: AppConfig.dns64WidgetKind)
        ControlCenter.shared.reloadControls(ofKind: AppConfig.dns64ControlKind)
    }
}

enum DNS64IntentError: Error, CustomLocalizedStringResourceConvertible {
    case noNode

    var localizedStringResource: LocalizedStringResource { "Connect a node with DNS64 in the app first." }
}

private extension String {
    nonisolated var nilIfEmpty: String? { isEmpty ? nil : self }
}

// MARK: - Intents

struct DNS64WidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "DNS64"
    static let description = IntentDescription("Blocking status of a DNS64 node.")
    @Parameter(title: "Node") var node: DNS64NodeEntity?
}

struct DNS64ControlIntent: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "DNS64 Blocking"
    @Parameter(title: "Node") var node: DNS64NodeEntity?
}

struct PauseDNS64Intent: AppIntent {
    static let title: LocalizedStringResource = "Pause DNS64 Blocking"
    @Parameter(title: "Node") var node: DNS64NodeEntity?
    /// 1-1440, 0 = until resumed.
    @Parameter(title: "Minutes", default: 15) var minutes: Int

    init() {}
    init(node: DNS64NodeEntity?, minutes: Int) {
        self.node = node
        self.minutes = minutes
    }

    func perform() async throws -> some IntentResult {
        try await DNS64Nodes.client(node?.id).dns64.pause(minutes: minutes)
        DNS64Nodes.reload()
        return .result()
    }
}

struct ResumeDNS64Intent: AppIntent {
    static let title: LocalizedStringResource = "Resume DNS64 Blocking"
    @Parameter(title: "Node") var node: DNS64NodeEntity?

    init() {}
    init(node: DNS64NodeEntity?) { self.node = node }

    func perform() async throws -> some IntentResult {
        try await DNS64Nodes.client(node?.id).dns64.resume()
        DNS64Nodes.reload()
        return .result()
    }
}

/// Control toggle: on = blocking active; off pauses until resumed, so the toggle state is exact.
struct SetDNS64BlockingIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Set DNS64 Blocking"
    @Parameter(title: "Node") var node: DNS64NodeEntity?
    @Parameter(title: "Blocking") var value: Bool

    init() {}
    init(node: DNS64NodeEntity?) { self.node = node }

    func perform() async throws -> some IntentResult {
        let dns = try DNS64Nodes.client(node?.id).dns64
        if value { try await dns.resume() } else { try await dns.pause(minutes: 0) }
        DNS64Nodes.reload()
        return .result()
    }
}

// MARK: - Control (iOS 18)

struct DNS64BlockingControl: ControlWidget {
    struct Value {
        let isOn: Bool
        let node: DNS64NodeEntity?
    }

    struct Provider: AppIntentControlValueProvider {
        func previewValue(configuration: DNS64ControlIntent) -> Value { Value(isOn: true, node: configuration.node) }

        func currentValue(configuration: DNS64ControlIntent) async throws -> Value {
            guard let resolved = DNS64Nodes.resolve(configuration.node?.id) else { throw DNS64IntentError.noNode }
            let blocking = try await resolved.client.dns64.status().blocking
            return Value(isOn: blocking?.paused != true, node: resolved.node)
        }
    }

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(kind: AppConfig.dns64ControlKind, provider: Provider()) { value in
            ControlWidgetToggle("DNS64 Blocking", isOn: value.isOn, action: SetDNS64BlockingIntent(node: value.node)) { isOn in
                Label(isOn ? "Active" : "Paused", systemImage: isOn ? "shield.lefthalf.filled" : "pause.circle")
            }
        }
        .displayName("DNS64 Blocking")
        .description("Pause or resume DNS64 blocking.")
    }
}
