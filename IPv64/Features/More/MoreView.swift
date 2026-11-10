import SwiftUI

/// "More" hub (tab root, spec 04 §1). Rows select the detail column (see Router.swift).
struct MoreView: View {
    @Environment(Session.self) private var session
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var router = router
        @Bindable var session = session
        List(selection: $router.selection) {
            Section("Account") {
                row("Account", systemImage: "person.crop.circle", route: .account)
                row("API keys", systemImage: "key", route: .apiKeys)
                row("Account links", systemImage: "link", route: .accountLinks)
            }
            Section("Nodes") {
                row("Nodes", subtitle: "Connect a node with its API key",
                    systemImage: "point.3.connected.trianglepath.dotted", route: .nodes)
            }
            Section("Notifications") {
                row("Channels", subtitle: "Where notifications are sent", systemImage: "bell.badge", route: .channels)
                row("Notification settings", subtitle: "Quiet hours and batching",
                    systemImage: "slider.horizontal.3", route: .notificationSettings)
            }
            Section("Security") {
                row("IP lookup & My IP", subtitle: "Your public IP and why an IP is on the blocklist",
                    systemImage: "magnifyingglass", route: .threatLookup(ip: nil))
                row("Password check", subtitle: "Was a password used in attacks? Stays on your device",
                    systemImage: "lock.rectangle", route: .passwordCheck)
                row("Honeypot", subtitle: "Attacks, ports and rankings of the Honeypot64 network",
                    systemImage: "ladybug", route: .honeypot)
            }
            Section("Tools") {
                row("Logs", systemImage: "exclamationmark.bubble", route: .logs)
            }
            Section("App") {
                Toggle(isOn: $session.lockscreenEnabled) {
                    ListRow("Lockscreen", subtitle: session.lockscreenEnabled ? "enabled" : "disabled",
                            systemImage: Biometrics.symbol)
                }
                row("About", systemImage: "info.circle", route: .about)
                Link(destination: URL(string: "https://www.youtube.com/c/RaspberryPiCloud")!) {
                    ListRow("YouTube", systemImage: "play.rectangle")
                }
                Link(destination: URL(string: "https://discord.gg/rpicloud")!) {
                    ListRow("Discord", systemImage: "bubble.left.and.bubble.right")
                }
            }
            Section {
                Button(role: .destructive) {
                    session.logout()
                } label: {
                    ListRow("Logout", systemImage: "rectangle.portrait.and.arrow.right",
                            iconTint: .ipv64Red, titleColor: .ipv64Red)
                }
            }
        }
        .navigationTitle("More")
    }

    private func row(_ title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil, systemImage: String,
                     route: Route) -> some View {
        NavigationLink(value: route) {
            ListRow(title, subtitle: subtitle, systemImage: systemImage)
        }
    }
}
