import SwiftUI
import IPv64

/// Node detail (spec 04 §4): cloud data + optional live data over the stored direct connection.
struct NodeDetailView: View {
    @Environment(Session.self) var session
    @Environment(ConnectedNodes.self) var nodes
    @Environment(Router.self) var router
    @Environment(\.scenePhase) var scenePhase

    let nodeId: String

    @State var info: NodeInfo?
    @State var loadFailed = false
    @State var planReason: String?
    @State var directOnly = false
    @State var access: LocalNodeStore.Access?
    @State var live = NodeLive()
    @State var spinner: LocalizedStringKey?
    @State var isRefreshing = false
    @State var error: ErrorText?
    @State var message: ErrorText?
    @State var popAfterMessage = false
    @State var confirm: ConfirmRequest?
    @State var sheet: DetailSheet?
    @State var pendingCommand: NodeCommand?
    @State var commands: [HC2Command] = []
    @State var historyOpen = false
    @State var historyLoading = false
    @State var historyLoaded = false
    @State var tracking: Int?

    enum DetailSheet: String, Identifiable {
        case edit, resolve, unlink
        var id: String { rawValue }
    }

    private struct LoadKey: Equatable {
        let reload: Int
        let active: Bool
        let account: Int
    }

    private struct TickKey: Equatable {
        let hasAccess: Bool
        let active: Bool
    }

    // MARK: Derived

    var isLocal: Bool { access != nil }
    var isBusy: Bool { spinner != nil }
    var localNode: Node64.NodeStatusNode? { live.status?.node }
    /// Node id reported by the address, if it differs from this node.
    var otherNodeId: String? {
        guard let id = localNode?.id?.nonBlank, id != nodeId else { return nil }
        return id
    }
    var storedName: String? { LocalNodeStore.name(nodeId) }
    var displayName: String {
        let name = directOnly ? (localNode?.name?.nonBlank ?? info?.name?.nonBlank ?? storedName) : info?.name
        return Formatters.nodeName(name, nodeId: nodeId)
    }
    var remote: String? { info?.remote }
    var canCommand: Bool { remote == "full" && !directOnly }
    var conflicts: Int { live.status?.link?.conflicts ?? info?.conflicts ?? 0 }
    var isLoading: Bool {
        if planReason != nil || loadFailed { return false }
        return info == nil || (isLocal && live.status == nil && !live.failing)
    }
    var loaded: Bool { info != nil && !isLoading }

    var body: some View {
        content
            .navigationTitle(info == nil ? "Node" : displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .task(id: LoadKey(reload: router.reloadToken, active: scenePhase == .active, account: session.accountRevision)) {
                access = nodes.access(for: nodeId)
                await loadCloud()
            }
            .task(id: TickKey(hasAccess: isLocal, active: scenePhase == .active)) { await tickLoop() }
            .task(id: tracking) { await trackCommand() }
            .onChange(of: historyOpen) { if historyOpen && !historyLoaded { Task { await loadCommands() } } }
            .refreshable { await refresh() }
            .loadingOverlay(isBusy, text: spinner ?? "Loading...")
            .errorAlert($error, retry: loadFailed ? { Task { await loadCloud() } } : nil)
            .errorAlert($message)
            .onChange(of: message) { if message == nil, popAfterMessage { popAfterMessage = false; router.reload(); router.pop() } }
            .confirmDialog($confirm)
            .sheet(item: $sheet, onDismiss: confirmPendingCommand) { sheet in
                switch sheet {
                case .edit:
                    NodeEditSheet(nodeId: nodeId, info: info ?? NodeInfo(name: nil)) { updated in
                        info = info?.merged(with: updated)
                        router.reload()
                    }
                case .resolve:
                    ResolveConflictSheet { pendingCommand = $0; self.sheet = nil }
                case .unlink:
                    NodeUnlinkSheet(nodeId: nodeId, name: displayName) { handleUnlink($0) }
                }
            }
    }

    @ViewBuilder private var content: some View {
        if let planReason, !isLocal {
            ScrollView { NotAvailableView(feature: "Nodes", reason: planReason) }
        } else if loadFailed {
            Color.clear
        } else if isLoading {
            LoadingView()
        } else if let info {
            detailList(info)
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        if loaded {
            ToolbarItem(placement: .primaryAction) {
                Button(directOnly ? "Edit connection" : "Edit", systemImage: "pencil") {
                    if directOnly { router.sheet = .directAccess(nodeId: nodeId) } else { sheet = .edit }
                }
                .disabled(isBusy)
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    if remote == "full" && !directOnly {
                        Button("Repair", systemImage: "wrench.and.screwdriver") { ask(NodeCommand(name: .repair)) }
                            .disabled(isBusy || tracking != nil)
                    }
                    if remote == "full" && !directOnly && conflicts > 0 {
                        Button("Resolve conflict", systemImage: "arrow.triangle.merge") { sheet = .resolve }
                    }
                    if isLocal && !directOnly {
                        Button("Edit direct connection", systemImage: "network") { router.sheet = .directAccess(nodeId: nodeId) }
                    }
                    if isLocal {
                        Button("Forget direct connection", systemImage: "network.slash") { askForget() }
                    }
                    if !directOnly {
                        Button("Unlink node", systemImage: "link.badge.minus", role: .destructive) { sheet = .unlink }
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
    }
}
