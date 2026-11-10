import SwiftUI
import IPv64

/// New / edit channel (spec 04 §6). New: type picker, then the form (Back returns to the picker).
struct ChannelSetupView: View {
    /// `nil` = new channel (type picker first).
    let channelId: Int?

    var body: some View {
        if let channelId {
            ChannelFormView(mode: .edit(channelId))
        } else {
            ChannelTypePicker()
        }
    }
}

/// Step 1: one row per `channels.types()` entry; "app" opens Push setup instead.
private struct ChannelTypePicker: View {
    @Environment(Session.self) private var session
    @Environment(Router.self) private var router

    @State private var types: [HC2ChannelType]?
    @State private var isLoading = false
    @State private var error: ErrorText?

    var body: some View {
        List {
            if let types {
                if types.isEmpty {
                    Text("No channel types available.").foregroundStyle(.secondary)
                }
                ForEach(types, id: \.self) { type in
                    if type.type == .app {
                        Button(action: openPushSetup) {
                            LabeledContent {
                                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                            } label: {
                                ChannelTypeLabel(type: type)
                            }
                        }
                        .tint(.primary)
                    } else {
                        NavigationLink {
                            ChannelFormView(mode: .new(type))
                        } label: {
                            ChannelTypeLabel(type: type)
                        }
                    }
                }
            }
        }
        .navigationTitle("New channel")
        .navigationBarTitleDisplayMode(.inline)
        .loadingOverlay(isLoading)
        .task { await load() }
        .errorAlert($error) { Task { await load() } }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        let client = session.api
        do {
            types = try await ipv64Retrying { try await client.hc2.channels.types() }
        } catch is CancellationError {
        } catch {
            self.error = ErrorText(error)
        }
    }

    /// Replaces this screen with Push setup (Android pops `channel_new` inclusive).
    private func openPushSetup() {
        router.pop()
        router.push(.pushSetup)
    }
}

private struct ChannelTypeLabel: View {
    let type: HC2ChannelType

    var body: some View {
        Label {
            if type.type == .app {
                Text("IPv64 App (this device)")
            } else {
                Text(verbatim: type.label?.nonBlank ?? type.type?.rawValue ?? "")
            }
            if type.needsVerification == true { Text("Needs verification") }
        } icon: {
            Image(systemName: ChannelLogic.systemImage(type: type.type?.rawValue))
        }
    }
}
