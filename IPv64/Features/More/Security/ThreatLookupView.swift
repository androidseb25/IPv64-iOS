import SwiftUI
import IPv64

/// IP lookup & My IP (spec 04 §11).
struct ThreatLookupView: View {
    /// Looked up immediately when given.
    var ip: String? = nil

    @Environment(Session.self) private var session

    @State private var ipv4: String?
    @State private var ipv6: String?
    @State private var loadingOwn = true
    @State private var query = ""
    @State private var fieldError: String?
    @State private var result: ThreatIP?
    @State private var isLooking = false
    @State private var error: ErrorText?
    @FocusState private var focused: Bool

    var body: some View {
        List {
            Section("Your public IP") {
                ownRow(ipv4, family: "IPv4")
                ownRow(ipv6, family: "IPv6")
            }
            Section {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("IP address", text: $query)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .focused($focused)
                        .onSubmit { lookup(query) }
                    Button("Look up", systemImage: "arrow.right.circle") { lookup(query) }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .disabled(isLooking)
                }
            } footer: {
                if let fieldError { Text(verbatim: fieldError).foregroundStyle(Color.ipv64Red) }
            }
            if let result { ThreatResultSections(result: result) }
        }
        .navigationTitle("IP lookup & My IP")
        .navigationBarTitleDisplayMode(.inline)
        .loadingOverlay(isLooking, text: "Looking up...")
        .task { await loadOwn() }
        .task { if let ip { lookup(ip) } }
        .errorAlert($error)
    }

    private func ownRow(_ address: String?, family: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                if let address {
                    Text(verbatim: address).font(.body.monospaced())
                } else {
                    Text(loadingOwn ? "Loading..." : "Not available").foregroundStyle(.secondary)
                }
                Text(verbatim: family).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            if let address {
                Button("Look up") { lookup(address) }
                    .buttonStyle(.bordered)
                    .disabled(isLooking)
            }
        }
    }

    private func loadOwn() async {
        async let v4 = session.myIP(.v4)
        async let v6 = session.myIP(.v6)
        ipv4 = await v4
        ipv6 = await v6
        loadingOwn = false
    }

    private func lookup(_ raw: String) {
        let normalized = SecurityLogic.normalizeIpInput(raw)
        guard SecurityLogic.isValidIP(normalized) else {
            fieldError = String(localized: "Enter a valid IPv4 or IPv6 address.")
            return
        }
        fieldError = nil
        result = nil
        query = normalized
        focused = false
        isLooking = true
        Task {
            defer { isLooking = false }
            do {
                result = try await ipv64Retrying { try await session.api.threat.ip(normalized) }
            } catch is CancellationError {
            } catch let failure as IPv64Error where failure.statusCode == 422 {
                var text = String(localized: "This is not a valid public IP address.")
                if case .api(let problem) = failure, let detail = problem.detail.nonBlank { text = detail }
                fieldError = text
            } catch {
                self.error = ErrorText(error)
            }
        }
    }
}
