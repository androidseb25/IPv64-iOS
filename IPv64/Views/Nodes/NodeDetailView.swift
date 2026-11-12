import SwiftUI
import IPv64

/// Node detail: cloud data (`hc2.nodes.get`) plus live data over the stored direct connection, if any.
/// Direct-only nodes (unknown to the account) show no checks, commands, cloud edit or unlink.
struct NodeDetailView: View {
    @Environment(Session.self) var session
    @Environment(ConnectedNodes.self) var nodes
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.dismiss) var dismiss

    let nodeId: String
    /// Tells the list that this node changed (edit, unlink, forget).
    let onChanged: () -> Void

    @State var info: NodeInfo?
    @State var loadFailed = false
    @State var planReason: String?
    @State var directOnly = false
    @State var access: LocalNodeStore.Access?
    @State var live = NodeLive()
    @State var busy = false
    @State var isLoading = false
    /// Mutex of the silent live refresh.
    @State var isTicking = false
    @State var error: ErrorText?
    @State var unlinkText: String?
    @State var pendingUnlink: String?
    @State var pendingError: ErrorText?
    @State var sheet: DetailSheet?
    @State var pendingCommand: NodeCommand?
    @State var confirmCommand: NodeCommand?
    @State var confirmDisable: String?
    @State var confirmForget = false
    @State var commands: [HC2Command] = []
    @State var historyOpen = false
    @State var historyLoading = false
    @State var historyLoaded = false
    @State var detailsOpen = false
    @State var tracking: Int?
    /// Name of the module whose screen is pushed.
    @State var moduleScreen: String?

    enum DetailSheet: String, Identifiable {
        case edit, connection, resolve, unlink
        var id: String { rawValue }
    }

    private struct TickKey: Equatable {
        let hasAccess: Bool
        let active: Bool
    }

    // MARK: Derived

    var isLocal: Bool { access != nil }
    var localNode: Node64.NodeStatusNode? { live.status?.node }
    /// Node id reported by the address, if it differs from this node.
    var otherNodeId: String? {
        guard let id = localNode?.id?.nonBlank, id != nodeId else { return nil }
        return id
    }
    var displayName: String {
        let name = directOnly ? (localNode?.name?.nonBlank ?? info?.name?.nonBlank ?? LocalNodeStore.name(nodeId)) : info?.name
        return NodesLogic.nodeName(name, nodeId: nodeId)
    }
    var canCommand: Bool { info?.remote == "full" && !directOnly }
    var conflicts: Int { live.status?.link?.conflicts ?? info?.conflicts ?? 0 }
    /// Cloud data there and, with direct access, the first live answer (or its failure).
    var loaded: Bool { info != nil && !(isLocal && live.status == nil && !live.failing) }
    var locked: Bool { busy || isLoading || !loaded }

    var body: some View {
        if #available(iOS 26.0, *) {
            content.setColorGradient(sheet != nil || confirmCommand != nil || confirmDisable != nil || confirmForget ? .clear : .orange)
        } else {
            content
        }
    }

    private var screen: some View {
        List {
            if loaded, let info { sections(info) }
        }
        .overlay { overlay }
        // While loading or running an action everything is locked; the spinner sits in the toolbar.
        .disabled(locked)
        .navigationTitle(info == nil ? String(localized: "Node") : displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .navigationDestination(for: HealthcheckRoute.self) { route in
            HealthcheckDetailView(token: route.token) { Task { await loadCloud() } }
        }
        .navigationDestination(item: $moduleScreen) { module in
            NodeModuleView(nodeId: nodeId, module: module)
        }
        .task { await start() }
        .task(id: TickKey(hasAccess: isLocal, active: scenePhase == .active)) { await tickLoop() }
        .task(id: tracking) { await trackCommand() }
        .onChange(of: historyOpen) { if historyOpen && !historyLoaded { Task { await loadCommands() } } }
        .refreshable { await refresh() }
        .sheet(item: $sheet, onDismiss: sheetClosed) { sheet in
            switch sheet {
            case .edit:
                NodeEditSheet(nodeId: nodeId, info: info ?? NodeInfo(name: nil)) { updated in
                    info = info?.merged(with: updated)
                    onChanged()
                }
            case .connection:
                NodeLocalSheet(nodeId: nodeId).onDisappear(perform: reloadAccess)
            case .resolve:
                ResolveConflictSheet { pendingCommand = $0 }
            case .unlink:
                NodeUnlinkSheet(nodeId: nodeId, name: displayName) { handleUnlink($0) }
            }
        }
    }

    private var content: some View {
        screen
        .alert(confirmCommand.map { "\($0.label)?" } ?? "", isPresented: Binding(
            get: { confirmCommand != nil }, set: { if !$0 { confirmCommand = nil } }), presenting: confirmCommand) { command in
            Button("Send", role: command.name == .resolveConflict ? .destructive : nil) { Task { await send(command) } }
            Button("Cancel", role: .cancel) {}
        } message: { command in
            Text(command.confirmText(nodeName: displayName))
        }
        .alert(confirmDisable.map { String(localized: "Disable \($0)?") } ?? "", isPresented: Binding(
            get: { confirmDisable != nil }, set: { if !$0 { confirmDisable = nil } }), presenting: confirmDisable) { name in
            Button("Disable", role: .destructive) { Task { await setModule(name, enable: false) } }
            Button("Cancel", role: .cancel) {}
        } message: { name in
            Text("Disable \(name)? Services of this module stop on the node, e.g. DNS for your network.")
        }
        .alert("Forget access?", isPresented: $confirmForget) {
            Button("Forget", role: .destructive) { forget() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The address and API key are removed from this device. The node itself is not changed.")
        }
        .alert("Node unlinked", isPresented: Binding(get: { unlinkText != nil }, set: { if !$0 { unlinkText = nil } }),
               presenting: unlinkText) { _ in
            Button("OK") { dismiss() }
        } message: { text in
            Text(text)
        }
        .errorAlert($error)
    }

    @ViewBuilder private var overlay: some View {
        if let planReason, !isLocal {
            ContentUnavailableView("Nodes not available", systemImage: "point.3.connected.trianglepath.dotted",
                                   description: Text(planReason))
        } else if loadFailed {
            ContentUnavailableView {
                Label("Node could not be loaded", systemImage: "exclamationmark.triangle")
            } actions: {
                Button("Retry") { Task { await loadCloud() } }
            }
        } else if !loaded {
            ProgressView()
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(directOnly ? "Edit connection" : "Edit", systemImage: "pencil") {
                sheet = directOnly ? .connection : .edit
            }
            .disabled(locked)
        }
        if #available(iOS 26.0, *) {
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
        }
        ToolbarItem(placement: .topBarTrailing) {
            if busy || isLoading {
                ProgressView()
            } else {
                moreMenu.disabled(!loaded)
            }
        }
    }

    private var moreMenu: some View {
        Menu {
            if !directOnly {
                Button(isLocal ? "Edit direct connection" : "Set up direct access", systemImage: "network") { sheet = .connection }
            }
            if canCommand {
                Button("Repair", systemImage: "wrench.and.screwdriver") { confirmCommand = NodeCommand(name: .repair) }
                    .disabled(tracking != nil)
                if conflicts > 0 {
                    Button("Resolve conflict", systemImage: "arrow.triangle.merge") { sheet = .resolve }
                }
            }
            Divider()
            if isLocal {
                DestructiveMenuButton("Forget access", systemImage: "network.slash") { confirmForget = true }
            }
            if !directOnly {
                DestructiveMenuButton("Unlink node", systemImage: "minus.circle") { sheet = .unlink }
            }
        } label: {
            Label("More actions", systemImage: "ellipsis")
        }
    }
}
