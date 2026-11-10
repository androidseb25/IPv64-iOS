import SwiftUI

@main
struct IPv64App: App {
    @State private var session: Session
    @State private var nodes: ConnectedNodes
    @State private var registrar: PushRegistrar

    init() {
        _ = iLogger.shared
        let session = Session()
        #if DEBUG
        // Mock smoke tests: `-MOCK_API http://localhost:8064 -MOCK_LOGIN demo` logs in without typing.
        if AppConfig.mockBase != nil, !session.isLoggedIn,
           let key = UserDefaults.standard.string(forKey: "MOCK_LOGIN"), !key.isEmpty {
            _ = session.login(apiKey: key, isFromUser: false)
        }
        #endif
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
