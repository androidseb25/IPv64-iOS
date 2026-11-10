import SwiftUI
import IPv64

/// Local DNS records (spec 03 §9).
struct NodeDnsRecordsView: View {
    let nodeId: String

    @Environment(ConnectedNodes.self) private var nodes

    @State private var records: [Node64.DNS64Record]?
    @State private var sheet: RecordSheet?
    @State private var confirm: ConfirmRequest?
    @State private var busy: LocalizedStringKey?
    @State private var error: ErrorText?

    enum RecordSheet: Identifiable {
        case new
        case edit(Node64.DNS64Record)
        var id: Int { if case .edit(let r) = self { r.id } else { -1 } }
    }

    private var dns: Node64.DNS64? { nodes.client(for: nodeId)?.dns64 }

    var body: some View {
        Group {
            if nodes.access(for: nodeId) == nil {
                ContentUnavailableView("No direct connection to this node.", systemImage: "network.slash")
            } else if let records {
                list(records)
            } else {
                LoadingView()
            }
        }
        .navigationTitle("Local DNS records")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if nodes.access(for: nodeId) != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add record", systemImage: "plus") { sheet = .new }
                }
            }
        }
        .sheet(item: $sheet) { item in
            switch item {
            case .new: NodeDnsRecordSheet(record: nil, onSave: { save($0, id: nil) }, onDelete: {})
            case .edit(let r): NodeDnsRecordSheet(record: r, onSave: { save($0, id: r.id) }, onDelete: { askDelete(r) })
            }
        }
        .confirmDialog($confirm)
        .loadingOverlay(busy != nil, text: busy ?? "Updating...")
        .errorAlert($error)
        .task { await reload() }
    }

    private func list(_ records: [Node64.DNS64Record]) -> some View {
        List {
            if records.isEmpty {
                ContentUnavailableView("No local DNS records yet.", systemImage: "list.bullet")
                    .listRowBackground(Color.clear)
            }
            ForEach(records) { record in
                HStack {
                    Button { sheet = .edit(record) } label: { row(record) }.buttonStyle(.plain)
                    Toggle("Enabled", isOn: Binding(get: { record.enabled != false }, set: { toggle(record, $0) }))
                        .labelsHidden()
                        .disabled(busy != nil)
                }
                .swipeActions(edge: .trailing) {
                    Button("Delete", systemImage: "trash", role: .destructive) { askDelete(record) }
                }
            }
        }
        .refreshable { await reload() }
    }

    private func row(_ r: Node64.DNS64Record) -> some View {
        var sub = "\(r.type.rawValue) · \(r.value) · TTL \(r.ttl.map(String.init) ?? "–")"
        if let comment = r.comment?.nonBlank { sub += "\n" + comment }
        return VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: r.name.nonBlank ?? "–").font(.headline)
            Text(verbatim: sub).font(.footnote.monospaced()).foregroundStyle(.secondary).lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func reload() async {
        guard let dns else { return }
        do { records = try await dns.records.list() } catch is CancellationError {} catch {
            if !Task.isCancelled { self.error = .node(error) }
            if records == nil { records = [] }
        }
    }

    /// Every write: spinner, call, then reload the list.
    private func act(_ operation: @escaping (Node64.DNS64) async throws -> Void) {
        guard let dns else { return }
        Task {
            busy = "Updating..."
            do { try await operation(dns) } catch { self.error = .node(error) }
            await reload()
            busy = nil
        }
    }

    private func toggle(_ r: Node64.DNS64Record, _ on: Bool) {
        act { on ? try await $0.records.enable(r.id) : try await $0.records.disable(r.id) }
    }

    private func save(_ input: Node64.DNS64RecordInput, id: Int?) {
        act { dns in
            if let id { _ = try await dns.records.update(id, input) } else { _ = try await dns.records.create(input) }
        }
    }

    private func askDelete(_ r: Node64.DNS64Record) {
        confirm = ConfirmRequest(title: String(localized: "Delete record"),
                                 message: String(localized: "Delete \(r.name) (\(r.type.rawValue))?"),
                                 confirmLabel: String(localized: "Delete"), destructive: true) {
            act { _ = try await $0.records.delete(r.id) }
        }
    }
}
