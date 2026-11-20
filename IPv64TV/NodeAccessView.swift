import SwiftUI

/// Node grid like the Home Screen: saved nodes (active one marked), nodes from the iPhone (iCloud) and a "+" tile
/// for manual entry. Long press on a saved node: edit or delete.
struct NodeAccessView: View {
    @Environment(TVSession.self) private var session
    @State private var connecting: String?
    @State private var error: String?
    @State private var editor: Editor?
    @State private var deleting: TVNode.Saved?
    @AppStorage(TVSettings.streamingMode) private var streaming = false
    @FocusState private var focused: String?

    /// Manual entry sheet: a new node, or a saved one being edited.
    struct Editor: Identifiable {
        var node: TVNode.Saved?
        var id: String { node?.id ?? "+" }
    }

    /// iCloud nodes not saved here yet, one per node (the same node can come from two ipv64.net accounts).
    private var suggestions: [NodeCloudStore.Node] {
        var seen = Set(session.saved.map(\.id)).union(session.saved.map(\.url))
        return (session.cloudNodes ?? []).filter { seen.insert($0.nodeId).inserted && seen.insert($0.url).inserted }
    }

    /// The Siri Remote starts on the first tile.
    private var firstTile: String { session.saved.first?.id ?? suggestions.first?.id ?? "+" }

    var body: some View {
        // Same header position as the dashboard (below the floating tab bar), Reload top right.
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Label("Nodes", systemImage: "server.rack").font(.largeTitle.bold())
                Spacer(minLength: 0)
                Button { Task { await session.loadCloudNodes() } } label: {
                    if session.loadingCloud { ProgressView() } else { Label("Reload", systemImage: "arrow.clockwise") }
                }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 380), spacing: 50)], spacing: 50) {
                        ForEach(session.saved) { node in
                            tile(title(node.name, node.url), shown(node.url), systemImage: "server.rack", active: node.id == session.activeId) {
                                TVNode.select(node.id)
                                session.reload()
                            }
                            .focused($focused, equals: node.id)
                            .contextMenu {
                                Button("Edit", systemImage: "pencil") { editor = Editor(node: node) }
                                Button("Delete", systemImage: "trash", role: .destructive) { deleting = node }
                            }
                        }
                        ForEach(suggestions) { node in
                            tile(title(node.name, node.url), shown(node.url), systemImage: "icloud", busy: connecting == node.id) {
                                Task { await connect(node) }
                            }
                            .focused($focused, equals: node.id)
                        }
                        tile(String(localized: "Add node"), String(localized: "Address and API key"), systemImage: "plus") { editor = Editor() }
                            .focused($focused, equals: "+")
                    }
                    footer
                }
                .padding(40)  // room for the focused tile's lift
            }
        }
        .tvPage()
        .focusSection()
        // .userInitiated: when the user moves down from the tab bar; closing a sheet or menu restores focus as usual.
        .defaultFocus($focused, firstTile, priority: .userInitiated)
        .onChange(of: session.cloudNodes?.count) {
            // First launch: the iCloud list arrives after the screen appeared with only "Add node" to focus.
            if focused == "+", firstTile != "+" { focused = firstTile }
        }
        .task { await session.loadCloudNodes() }
        .alert("Could not connect", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") {}
        } message: { Text(error ?? "") }
        .fullScreenCover(item: $editor) { editor in ManualNodeView(node: editor.node) }
        .confirmationDialog("Delete \(deleting.map { title($0.name, $0.url) } ?? "")?",
                            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            titleVisibility: .visible, presenting: deleting) { node in
            Button("Delete", role: .destructive) {
                TVNode.forget(node.id)
                session.reload()
            }
        } message: { _ in
            Text("The node is removed from this Apple TV only.")
        }
    }

    /// iCloud state below the grid.
    @ViewBuilder private var footer: some View {
        Group {
            if let cloudError = session.cloudError {
                Text(cloudError)
            } else if session.cloudNodes == nil {
                ProgressView()
            } else if session.cloudNodes?.isEmpty == true {
                Text("No nodes from your iPhone yet. Turn on \"Sync with iCloud\" in the iPhone app under More → Nodes.")
            }
        }
        .foregroundStyle(.secondary)
    }

    private func tile(_ title: String, _ subtitle: String, systemImage: String, active: Bool = false, busy: Bool = false,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: systemImage).font(.title2).foregroundStyle(Color.ipv64)
                    Spacer()
                    if busy { ProgressView() } else if active { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                }
                Spacer(minLength: 0)
                Text(title).font(.headline).lineLimit(1)
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            .padding(30)
            .frame(width: 380, height: 220, alignment: .leading)
        }
        .buttonStyle(.card)
        .disabled(connecting != nil)
    }

    private func shown(_ url: String) -> String { streaming ? Streaming.maskURL(url) : url }
    private func title(_ name: String?, _ url: String) -> String { name.map { Streaming.name($0, streaming: streaming) } ?? shown(url) }

    private func connect(_ node: NodeCloudStore.Node) async {
        connecting = node.id
        defer { connecting = nil }
        do {
            try await TVNode.connect(address: node.url, key: node.key, id: node.nodeId)
            _ = TVNode.adopt([node])  // remembers this iCloud state as seen
            error = nil
            session.reload()
        } catch {
            self.error = "\(title(node.name, node.url)): \(Streaming.errorText(error, streaming: streaming))"
        }
    }
}

/// Address and API key of a new node, or of a saved one (empty key keeps the stored key). Full screen:
/// explanation left, fields and a prominent Connect button right; Menu on the remote closes it.
struct ManualNodeView: View {
    let node: TVNode.Saved?
    @Environment(TVSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var key = ""
    @State private var connecting = false
    @State private var error: String?
    @AppStorage(TVSettings.streamingMode) private var streaming = false

    var body: some View {
        HStack(spacing: 100) {
            VStack(alignment: .leading, spacing: 30) {
                Image(systemName: node == nil ? "plus.circle.fill" : "pencil.circle.fill")
                    .font(.system(size: 120))
                    .foregroundStyle(Color.ipv64)
                Text(node == nil ? "Add node" : "Edit node").font(.largeTitle.bold())
                Text("Enter the address and API key of your Node64 node, as in the iPhone app under More → Nodes.")
                Label("Type on your iPhone: tap the keyboard notification.", systemImage: "iphone")
                    .foregroundStyle(.secondary)
            }
            .frame(width: 650, alignment: .leading)
            // Fields on a light card with their own capsules: tvOS draws unfocused fields without a platter.
            VStack(alignment: .leading, spacing: 30) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Address").font(.headline).foregroundStyle(.secondary)
                    // Streaming mode: the stored address is not prefilled; empty keeps it.
                    TextField(streaming && node != nil ? Streaming.maskURL(node!.url) : "e.g. 192.168.1.10", text: $address)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .background(.white.opacity(0.12), in: Capsule())  // unfocused tvOS fields draw no platter
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Node API key").font(.headline).foregroundStyle(.secondary)
                    SecureField(node == nil ? "node64_…" : "Empty keeps the stored key", text: $key)
                        .background(.white.opacity(0.12), in: Capsule())
                }
                Button {
                    Task { await connect() }
                } label: {
                    Group {
                        if connecting { ProgressView() } else { Text(node == nil ? "Connect" : "Save").bold() }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.ipv64)
                .disabled(connecting)
                Button {
                    dismiss()
                } label: {
                    Text("Cancel").frame(maxWidth: .infinity)
                }
            }
            .padding(50)
            .frame(width: 850)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 40))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // A full-screen cover is transparent on tvOS: an opaque background hides the grid behind it.
        .background {
            LinearGradient(colors: [Color.ipv64.opacity(0.25), .black], startPoint: .top, endPoint: .center)
                .background(.black)
                .ignoresSafeArea()
        }
        .onAppear { if address.isEmpty && !streaming { address = node?.url ?? "" } }
        .alert("Could not connect", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") {}
        } message: { Text(error ?? "") }
    }

    private func connect() async {
        connecting = true
        defer { connecting = false }
        do {
            // Streaming mode does not prefill the stored address: empty keeps it. Without it, empty stays an input error.
            try await TVNode.connect(address: address.isEmpty && streaming ? node?.url ?? "" : address, key: key, replacing: node?.id)
            session.reload()
            dismiss()
        } catch {
            self.error = Streaming.errorText(error, streaming: streaming)
        }
    }
}
