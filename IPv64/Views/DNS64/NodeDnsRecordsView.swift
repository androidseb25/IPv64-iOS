import SwiftUI
import IPv64

/// Local DNS records of a node: enable toggle, create/edit sheet, swipe to delete.
struct NodeDnsRecordsView: View {
    let nodeId: String

    @Environment(ConnectedNodes.self) private var nodes

    @State private var records: [Node64.DNS64Record]?
    @State private var sheet: RecordSheet?
    @State private var toDelete: Node64.DNS64Record?
    @State private var busy = false
    @State private var error: ErrorText?

    enum RecordSheet: Identifiable {
        case new
        case edit(Node64.DNS64Record)
        var id: Int { if case .edit(let r) = self { r.id } else { -1 } }
    }

    private var dns: Node64.DNS64? { nodes.client(for: nodeId)?.dns64 }

    var body: some View {
        if #available(iOS 26.0, *) {
            content.setColorGradient(sheet != nil ? .clear : .orange)
        } else { content }
    }

    private var content: some View {
        Group {
            if dns == nil {
                ContentUnavailableView("No direct connection to this node.", systemImage: "network.slash")
            } else if let records {
                list(records)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Local DNS records")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if dns != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add record", systemImage: "plus") { sheet = .new }
                }
            }
        }
        .sheet(item: $sheet) { item in
            switch item {
            case .new:
                NodeDnsRecordSheet(record: nil, onSave: { try await save($0, id: nil) }, onDelete: {})
            case .edit(let r):
                NodeDnsRecordSheet(record: r, onSave: { try await save($0, id: r.id) }, onDelete: { try await delete(r) })
            }
        }
        .alert("Delete record", isPresented: Binding(get: { toDelete != nil }, set: { if !$0 { toDelete = nil } }),
               presenting: toDelete) { r in
            Button("Delete", role: .destructive) { act { try await delete(r) } }
            Button("Cancel", role: .cancel) {}
        } message: { r in
            Text("Delete \(r.name) (\(r.type.rawValue))?")
        }
        .showLoading($busy)
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
                        .disabled(busy)
                }
                .swipeActions(edge: .trailing) {
                    Button("Delete", systemImage: "trash", role: .destructive) { toDelete = record }
                        .labelStyle(.iconOnly)
                        .tint(.red)
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

    /// Spinner, call, then reload the list.
    private func act(_ operation: @escaping () async throws -> Void) {
        Task {
            busy = true
            do { try await operation() } catch { self.error = .node(error) }
            await reload()
            busy = false
        }
    }

    private func toggle(_ r: Node64.DNS64Record, _ on: Bool) {
        guard let dns else { return }
        act { on ? try await dns.records.enable(r.id) : try await dns.records.disable(r.id) }
    }

    /// Used by the sheet, which shows the error itself and stays open on failure.
    private func save(_ input: Node64.DNS64RecordInput, id: Int?) async throws {
        guard let dns else { return }
        if let id { _ = try await dns.records.update(id, input) } else { _ = try await dns.records.create(input) }
        await reload()
    }

    private func delete(_ r: Node64.DNS64Record) async throws {
        guard let dns else { return }
        try await dns.records.delete(r.id)
        await reload()
    }
}
