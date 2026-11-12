import SwiftUI
import IPv64

/// Picks one of the account's domains and adds it to the CDN.
struct CdnAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(Session.self) private var session
    let exclude: Set<String>
    let onAdded: () -> Void

    @State private var names: [String]?
    @State private var selected: String?
    @State private var busy = false
    @State private var error: ErrorText?

    var body: some View {
        DynDNSSheet(title: "Add domain to CDN", confirmLabel: "Add", confirmEnabled: selected != nil,
                    isBusy: busy, onConfirm: { Task { await add() } }) {
            if let names {
                Section {
                    ForEach(names, id: \.self) { name in
                        Button { selected = name } label: {
                            HStack {
                                Text(name).foregroundStyle(.primary)
                                Spacer()
                                if selected == name { Image(systemName: "checkmark").foregroundStyle(.tint) }
                            }
                        }
                    }
                } footer: {
                    if names.isEmpty { Text("No domains available.") }
                }
            } else {
                Section { HStack { Spacer(); ProgressView(); Spacer() } }
            }
        }
        .task { await load() }
        .errorAlert($error)
        .presentationDetents([.large])
    }

    private func load() async {
        let api = session.api
        do {
            names = try await ipv64Retrying { try await api.domains.list() }
                .compactMap { $0.name?.nonBlank }.filter { !exclude.contains($0) }
                .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        } catch is CancellationError {
        } catch {
            names = []
            self.error = ErrorText(error)
        }
    }

    private func add() async {
        guard let selected else { return }
        let api = session.api
        busy = true
        defer { busy = false }
        do {
            _ = try await ipv64Retrying { try await api.cdn.add(domain: selected) }
            onAdded()
            dismiss()
        } catch {
            self.error = ErrorText(error)
        }
    }
}
