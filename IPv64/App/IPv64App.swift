import SwiftUI

@main
struct IPv64App: App {
    @State private var session: Session
    @State private var nodes: ConnectedNodes
    @State private var registrar: PushRegistrar

    init() {
        _ = iLogger.shared
        let session = Session()
        _session = State(initialValue: session)
        _nodes = State(initialValue: ConnectedNodes(session: session))
        _registrar = State(initialValue: PushRegistrar(session: session))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(nodes)
                .environment(registrar)
        }
    }
}
