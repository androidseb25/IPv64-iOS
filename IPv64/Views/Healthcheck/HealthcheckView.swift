import SwiftUI
import IPv64

/// Healthchecks 2.0 of the account (API v2): compact rows with a status tag, status filter, swipe actions.
struct HealthcheckView: View {
    @Environment(Session.self) private var session
    @Binding var popToRootTab: Tabs
    @State private var checks: [HC2Check]?
    @State private var status = HcStatusFilter.all
    @State private var exec = HcExecFilter.all
    @State private var busyTokens: Set<String> = []
    /// Removed at once while the delete request runs; back on failure.
    @State private var deletedTokens: Set<String> = []
    @State private var confirmDelete: HC2Check?
    @State private var error: ErrorText?

    private var all: [HC2Check] { (checks ?? []).filter { !deletedTokens.contains($0.token) } }

    private var visible: [HC2Check] {
        all.filter { status.matches(Hc2StateUi.from($0)) && exec.matches($0.execution) }
            .sorted { ($0.name ?? "").localizedStandardCompare($1.name ?? "") == .orderedAscending }
    }

    private var showsExecFilter: Bool { all.contains { ($0.execution ?? .online) != .online } || exec != .all }

    var body: some View {
        if #available(iOS 26.0, *) {
            listView.setColorGradient(confirmDelete != nil ? .clear : .orange)
        } else {
            listView
        }
    }

    private var listView: some View {
        List(visible) { check in
            HealthcheckItemView(check: check, isBusy: busyTokens.contains(check.token))
                .swipeActions {
                    Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = check }
                    if check.paused == true {
                        Button("Resume", systemImage: "play") { Task { await setPaused(check, false) } }
                            .tint(.green)
                    } else {
                        Button("Pause", systemImage: "pause") { Task { await setPaused(check, true) } }
                            .tint(.teal)
                    }
                }
        }
        .overlay { emptyState }
        .navigationTitle(Tabs.healthcheck.labelNew)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .refreshable { await load() }
        .task { await load() }
        .alert("Delete healthcheck?", isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } }),
               presenting: confirmDelete) { check in
            Button("Delete", role: .destructive) { Task { await delete(check) } }
            Button("Cancel", role: .cancel) {}
        } message: { check in
            Text("Do you really want to delete \"\(check.name ?? check.token)\"? Its history is deleted as well.")
        }
        .errorAlert($error)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Status", selection: $status) {
                    ForEach(HcStatusFilter.allCases, id: \.self) { filter in
                        Text(verbatim: "\(filter.label) (\(count(filter)))").tag(filter)
                    }
                }
                if showsExecFilter {
                    Picker("Runs on", selection: $exec) {
                        ForEach(HcExecFilter.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                }
            } label: {
                Label("Filter healthchecks", systemImage: status == .all && exec == .all
                      ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
            }
        }
    }

    @ViewBuilder private var emptyState: some View {
        if checks == nil {
            ProgressView("Loading healthchecks…")
        } else if visible.isEmpty {
            ContentUnavailableView(all.isEmpty ? "No healthchecks yet" : "No matching healthchecks",
                                   systemImage: "bolt.heart")
        }
    }

    private func count(_ filter: HcStatusFilter) -> Int {
        all.filter { filter.matches(Hc2StateUi.from($0)) }.count
    }

    private func load() async {
        let api = session.api
        do {
            checks = try await ipv64Retrying { try await api.hc2.checks.list() }
        } catch is CancellationError {
        } catch {
            if checks == nil { checks = [] }
            self.error = ErrorText(error)
        }
    }

    private func setPaused(_ check: HC2Check, _ paused: Bool) async {
        let api = session.api
        busyTokens.insert(check.token)
        defer { busyTokens.remove(check.token) }
        do {
            let updated = try await ipv64Retrying {
                paused ? try await api.hc2.checks.pause(check.token) : try await api.hc2.checks.resume(check.token)
            }
            if let index = checks?.firstIndex(where: { $0.token == check.token }) { checks?[index] = updated }
        } catch {
            self.error = ErrorText(error)
        }
    }

    private func delete(_ check: HC2Check) async {
        let api = session.api
        _ = withAnimation { deletedTokens.insert(check.token) }
        do {
            try await ipv64Retrying { try await api.hc2.checks.delete(check.token) }
            checks?.removeAll { $0.token == check.token }
        } catch {
            _ = withAnimation { deletedTokens.remove(check.token) }
            self.error = ErrorText(error)
        }
    }
}

#Preview { NavigationStack { HealthcheckView(popToRootTab: .constant(.healthcheck)) } }
