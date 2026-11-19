import SwiftUI

@main
struct IPv64TVApp: App {
    @State private var session = TVSession()
    /// Start tab; only set by the launch argument `-tvInitialTab <0-3>` (screenshots), otherwise the dashboard.
    @State private var tab = UserDefaults.standard.integer(forKey: "tvInitialTab")

    var body: some Scene {
        WindowGroup {
            Group {
                if session.client == nil {
                    NodeAccessView()
                } else {
                    TabView(selection: $tab) {
                        Tab("Dashboard", systemImage: "house", value: 0) { DashboardView() }
                        Tab("Query log", systemImage: "list.bullet.rectangle", value: 1) { QueryLogView() }
                        Tab("Nodes", systemImage: "server.rack", value: 2) { NodeAccessView() }
                        Tab("Settings", systemImage: "gear", value: 3) { SettingsView() }
                    }
                }
            }
            .environment(session)
            .task { await session.loadCloudNodes() }  // picks up key/address changes from the iPhone at launch
        }
    }
}
