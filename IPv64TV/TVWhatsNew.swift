import SwiftUI

/// Introduction shown once per new build (and from Settings → About). The TV app ships first with 2.3.0.
struct TVWhatsNewView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    private struct Entry: Identifiable {
        let icon: String, title: LocalizedStringKey, subtitle: LocalizedStringKey
        var id: String { icon }
    }

    private let entries = [
        Entry(icon: "house", title: "Dashboard", subtitle: "DNS64 of your Node64 at a glance: queries, blocked share, a chart and the latest queries."),
        Entry(icon: "list.bullet.rectangle", title: "Query log", subtitle: "Recent queries, filter by blocked or allowed, and block or allow a domain right from the TV."),
        Entry(icon: "icloud", title: "Nodes from your iPhone", subtitle: "Nodes you connect in the iPhone app appear here via iCloud; no typing with the remote."),
        Entry(icon: "eye.slash", title: "Streaming mode", subtitle: "Hides addresses, IPs, client names and domains while you stream or film the screen."),
        Entry(icon: "character.bubble", title: "German", subtitle: "The app is now also available in German."),
    ]

    var body: some View {
        VStack(spacing: 32) {
            Text("What's New in IPv64.net").font(.largeTitle.bold())
            VStack(alignment: .leading, spacing: 22) {
                ForEach(entries) { entry in
                    HStack(spacing: 32) {
                        Image(systemName: entry.icon)
                            .font(.system(size: 52))
                            .foregroundStyle(Color.ipv64)
                            .frame(width: 90)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.title).font(.title3.bold())
                            Text(entry.subtitle).font(.callout).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .frame(maxWidth: 1400, alignment: .leading)
            Button("Continue") { dismiss() }
                .focused($focused)
        }
        .padding(.horizontal, 60)
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // A full-screen cover is transparent on tvOS: an opaque background hides the tabs behind it.
        .background {
            LinearGradient(colors: [Color.ipv64.opacity(0.25), .black], startPoint: .top, endPoint: .center)
                .background(.black)
                .ignoresSafeArea()
        }
        .defaultFocus($focused, true)
    }
}
