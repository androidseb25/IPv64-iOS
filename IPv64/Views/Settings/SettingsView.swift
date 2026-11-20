//
//  SettingsView.swift
//  IPv64
//
//  Created by Sebastian Rank on 20.10.25.
//

import SwiftUI

struct SettingsView: View {
    
    @Environment(\.colorScheme) var systemColorScheme
    
    @Binding var popToRootTab: Tabs
    
    @StateObject private var userStorage = UserStorage.shared
    
    @State private var alertType: AlertType?
    @Environment(ConnectedNodes.self) private var nodes
    @AppStorage(NodeSyncStore.enabledKey, store: UserStorage.sharedDefault) private var syncNodes = true

    private static let apiKeysRoute = "settings.apikeys"
    private static let accountLinksRoute = "settings.accountlinks"
    private static let notificationSettingsRoute = "settings.notificationsettings"
    private static let passwordCheckRoute = "settings.passwordcheck"
    private static let honeypotRoute = "settings.honeypot"

    private func open(_ link: String) {
        if let url = URL(string: link) { UIApplication.shared.open(url) }
    }
    
    var body: some View {
            if #available(iOS 26.0, *) {
                listView
                    .setColorGradient(.orange)
            } else {
                listView
            }
    }
    
    private var listView: some View {
        // Groups and order as in Android 2.1.0 (More); plain rows as in the 2.0 app.
        List {
            Section("Account") {
                NavigationLink(value: Tabs.account.route) { Text("Account") }
                NavigationLink(value: Self.apiKeysRoute) { Text("API keys") }
                NavigationLink(value: Self.accountLinksRoute) { Text("Account links") }
            }

            Section {
                NavigationLink(value: NodesView.route) { Text("Nodes") }
                Toggle("Sync with iCloud", isOn: $syncNodes)
                    .onChange(of: syncNodes) { _, on in if on { nodes.syncWithCloud(force: true) } }
            } footer: {
                Text("Node URLs and API keys sync end-to-end encrypted through your iCloud Keychain.")
            }

            Section("Notifications") {
                NavigationLink(value: Tabs.notification.route) { Text("Channels") }
                NavigationLink(value: Self.notificationSettingsRoute) { Text("Notification settings") }
            }

            Section("Security") {
                NavigationLink(value: Tabs.myip.route) { Text("IP lookup & My IP") }
                NavigationLink(value: Self.passwordCheckRoute) { Text("Password check") }
                NavigationLink(value: Self.honeypotRoute) { Text("Honeypot") }
            }

            Section("Tools") {
                NavigationLink(value: Tabs.log.route) { Text("Logs") }
                NavigationLink(value: Tabs.syslog.route) { Text("System Logs") }
            }

            Section("App") {
                Toggle("Lock screen", isOn: $userStorage.EnableLogscreen)
                Toggle("Screenshot protection", isOn: $userStorage.ScreenshotProtection)
                LabeledContent("Version", value: "\(Bundle.main.versionNumber) (\(Bundle.main.buildNumber))")
                NavigationLink(value: Tabs.about.route) { Text("About") }
                Button { open("https://www.youtube.com/c/RaspberryPiCloud") } label: { ExternalLinkRow(title: "YouTube") }
                    .tint(.primary)
                Button { open("https://discord.gg/rpicloud") } label: { ExternalLinkRow(title: "Discord") }
                    .tint(.primary)
            }

            Section {
            Button(role: .destructive) {
                withAnimation {
                    alertType = .logout
                }
            } label: {
                Text("Logout")
            }
            }
        }
        .navigationTitle(Tabs.settings.labelNew)
        .navigationBarTitleDisplayMode(.inline).navigationDestination(for: String.self) { route in
            switch route {
            case Tabs.account.route:
                Tabs.account.makeContentView(popToRootTab: $popToRootTab)
            case Tabs.notification.route:
                Tabs.notification.makeContentView(popToRootTab: $popToRootTab)
            case Tabs.log.route:
                Tabs.log.makeContentView(popToRootTab: $popToRootTab)
            case Tabs.myip.route:
                Tabs.myip.makeContentView(popToRootTab: $popToRootTab)
            case Tabs.about.route:
                Tabs.about.makeContentView(popToRootTab: $popToRootTab)
            case NodesView.route:
                NodesView()
            case Self.apiKeysRoute:
                ApiKeysView()
            case Self.accountLinksRoute:
                AccountLinksView()
            case Self.notificationSettingsRoute:
                NotificationSettingsView()
            case Self.passwordCheckRoute:
                PasswordCheckView()
            case Self.honeypotRoute:
                HoneypotView()
            case Tabs.syslog.route:
                Tabs.syslog.makeContentView(popToRootTab: $popToRootTab)
            default:
                EmptyView()
            }
        }
        .alert(item: $alertType) { type in
            switch type {
            case .logout:
                return Alert(
                    title: Text("Are you sure you want to logout?"),
                    message: Text("You will need to sign in again to access your account."),
                    primaryButton: .destructive(Text("Logout")) {
                        withAnimation {
                            if(performLogout()) {
                                if (!User.empty.list.isEmpty) {
                                    self.alertType = .logoutSuccess
                                }
                            }
                        }
                    },
                    secondaryButton: .cancel()
                )
            case .logoutSuccess:
                return Alert(title: Text("Successfully logged out."), message: Text("The app selected the first available user in the list."), dismissButton: .cancel(Text("OK")))
            default:
                return Alert(title: Text(""))
            }
        }
    }
}

#Preview {
    SettingsView(popToRootTab: .constant(.settings))
        .environment(ConnectedNodes())
}

/// Row label for a link that leaves the app: title plus the trailing external-link arrow.
private struct ExternalLinkRow: View {
    let title: LocalizedStringKey

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
    }
}
