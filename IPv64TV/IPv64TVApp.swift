import SwiftUI

@main
struct IPv64TVApp: App {
    @State private var session = TVSession()
    /// Start tab; only set by the launch argument `-tvInitialTab <0-3>` (screenshots), otherwise the dashboard.
    @State private var showWhatsNew = false
    @State private var tab = UserDefaults.standard.integer(forKey: "tvInitialTab")

    private static let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""

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
            .fullScreenCover(isPresented: $showWhatsNew, onDismiss: {
                UserDefaults.standard.set(Self.build, forKey: TVSettings.lastWhatsNewBuild)
            }) { TVWhatsNewView() }
            // Once per new build, only when set up and not for the screenshot launch (-tvInitialTab).
            .onChange(of: session.client != nil, initial: true) { _, ready in
                guard ready, UserDefaults.standard.object(forKey: "tvInitialTab") == nil, UserDefaults.standard.string(forKey: TVSettings.lastWhatsNewBuild) != Self.build else { return }
                showWhatsNew = true
            }
            .task { await session.loadCloudNodes() }  // picks up key/address changes from the iPhone at launch
        }
    }
}
