import SwiftUI
import IPv64

struct SettingsView: View {
    @Environment(TVSession.self) private var session
    @AppStorage(TVSettings.keepAwake) private var keepAwake = true
    @AppStorage(TVSettings.streamingMode) private var streaming = false
    @State private var dnsVersion: String?
    @State private var showWhatsNew = false

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        return "\(info?["CFBundleShortVersionString"] as? String ?? "–") (\(info?["CFBundleVersion"] as? String ?? "–"))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Label("Settings", systemImage: "gear").font(.largeTitle.bold())
            Form {
                Section("Dashboard") {
                    Toggle("Keep the screen awake", isOn: $keepAwake)
                }
                Section {
                    Toggle("Streaming mode", isOn: $streaming)
                } footer: {
                    Text("Hides addresses, IPs, client names and domains, e.g. while you stream or film the screen.")
                }
                Section("Node") {
                    LabeledContent("Name", value: TVNode.name.map { Streaming.name($0, streaming: streaming) } ?? "–")
                    LabeledContent("Address", value: TVNode.url.map { streaming ? Streaming.maskURL($0) : $0 } ?? "–")
                    LabeledContent("DNS64 version", value: dnsVersion ?? "–")
                }
                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    Button("What's New") { showWhatsNew = true }
                }
            }
            .tvFocusRoom()
        }
        .tvPage()
        .fullScreenCover(isPresented: $showWhatsNew) { TVWhatsNewView() }
        .task(id: session.generation) {
            dnsVersion = nil
            dnsVersion = try? await session.client?.dns64.status().version
        }
    }
}
