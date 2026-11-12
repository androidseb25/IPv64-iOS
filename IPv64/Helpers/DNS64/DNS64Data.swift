import SwiftUI
import IPv64

/// Failure of one dashboard section: the section shows `text`, the others render normally.
nonisolated struct DnsSectionError: Error, Sendable { let text: String }
typealias DnsSec<T: Sendable> = Result<T, DnsSectionError>

/// Runs one section request; HTTP 404 becomes "Not available on this node.", else "<title>: <text>".
nonisolated func dnsSec<T: Sendable>(_ operation: @Sendable () async throws -> T) async -> DnsSec<T> {
    do {
        return .success(try await operation())
    } catch {
        if (error as? Node64Error)?.statusCode == 404 {
            return .failure(.init(text: String(localized: "Not available on this node.")))
        }
        return .failure(.init(text: ErrorText.node(error).titledText))
    }
}

/// Everything the dashboard shows for one node and range.
nonisolated struct DnsData: Sendable {
    let nodeId: String
    var blocking: DnsSec<Node64.DNS64Blocking?>
    var summary: DnsSec<Node64.DNS64Summary>
    var timeline: DnsSec<Node64.DNS64Timeline>
    var upstreams: DnsSec<Node64.DNS64Upstreams>
    var cache: DnsSec<Node64.DNS64Cache>
    var blocked: DnsSec<[Node64.DNS64TopItem]>
    var allowed: DnsSec<[Node64.DNS64TopItem]>
    var clients: DnsSec<[Node64.DNS64TopItem]>

    /// All sections in parallel.
    static func load(nodeId: String, dns: Node64.DNS64, range: Node64.DNS64Range) async -> DnsData {
        async let status = dnsSec { try await dns.status().blocking }
        async let summary = dnsSec { try await dns.summary(range: range) }
        async let timeline = dnsSec { try await dns.timeline(range: range) }
        async let upstreams = dnsSec { try await dns.upstreams.list() }
        async let cache = dnsSec { try await dns.cache.get() }
        async let blocked = dnsSec { try await dns.top(kind: .blocked, range: range, limit: 10) }
        async let allowed = dnsSec { try await dns.top(kind: .allowed, range: range, limit: 10) }
        async let clients = dnsSec { try await dns.top(kind: .clients, range: range, limit: 10) }
        return await DnsData(nodeId: nodeId, blocking: status, summary: summary, timeline: timeline, upstreams: upstreams,
                             cache: cache, blocked: blocked, allowed: allowed, clients: clients)
    }
}

enum DnsRange: CaseIterable, Identifiable {
    case hour, day, week
    var id: Self { self }
    var node: Node64.DNS64Range { switch self { case .hour: .lastHour; case .day: .last24Hours; case .week: .last7Days } }
    var hours: Int { switch self { case .hour: 1; case .day: 24; case .week: 168 } }
    var label: LocalizedStringKey { switch self { case .hour: "1 h"; case .day: "24 h"; case .week: "7 d" } }
}

/// Runs a write behind the screen's busy overlay; node errors become an alert.
@MainActor struct DnsActions {
    let busy: Binding<Bool>
    let error: Binding<ErrorText?>

    func run(_ operation: () async throws -> Void) async {
        busy.wrappedValue = true
        defer { busy.wrappedValue = false }
        do { try await operation() } catch is CancellationError {} catch { self.error.wrappedValue = .node(error) }
    }
}
