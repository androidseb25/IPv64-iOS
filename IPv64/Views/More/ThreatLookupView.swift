import SwiftUI
import IPv64

/// "IP lookup & My IP": own addresses on top, search below, result underneath.
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
                if let fieldError { Text(verbatim: fieldError).foregroundStyle(.red) }
            }
            if let result { ThreatResultSections(result: result) }
        }
        .navigationTitle("IP lookup & My IP")
        .navigationBarTitleDisplayMode(.inline)
        .moreGradient()
        .moreToolbarSpinner(isLooking)
        .task { await loadOwn() }
        .task { if let ip { lookup(ip) } }
        .errorAlert($error)
    }

    private func ownRow(_ address: String?, family: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                if let address {
                    Text(verbatim: address).font(.body.monospaced())
                } else if loadingOwn {
                    ProgressView()
                } else {
                    Text("Not available").foregroundStyle(.secondary)
                }
                Text(verbatim: family).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            if let address {
                Button("Copy", systemImage: "document.on.document") { Clipboard.copy(address) }
                    .labelStyle(.iconOnly)
                Button("Look up") { lookup(address) }
                    .disabled(isLooking)
            }
        }
        .buttonStyle(.borderless)
    }

    private func loadOwn() async {
        async let v4 = session.myIP(.v4)
        async let v6 = session.myIP(.v6)
        ipv4 = await v4
        ipv6 = await v6
        loadingOwn = false
    }

    private func lookup(_ raw: String) {
        let normalized = MoreLogic.normalizeIpInput(raw)
        guard MoreLogic.isValidIP(normalized) else {
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

/// Result sections of an IP lookup; empty rows and sections stay hidden.
struct ThreatResultSections: View {
    let result: ThreatIP
    @Environment(\.openURL) private var openURL

    private var status: (text: String, color: Color) {
        switch result.status {
        case .listed: (String(localized: "Listed"), .red)
        case .notListed: (String(localized: "Not listed"), .green)
        case .released: (String(localized: "Released"), .orange)
        case .allowlisted: (String(localized: "Allowlisted"), .teal)
        default: result.listed == true ? (String(localized: "Listed"), .red) : (String(localized: "Not listed"), .green)
        }
    }

    var body: some View {
        Section("Result") {
            HStack {
                Text(verbatim: result.ip ?? "").font(.body.monospaced()).textSelection(.enabled)
                Spacer()
                MoreTag(status.text, status.color)
            }
            if let score = result.score {
                let value = min(max(score, 0), 100)
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: "\(value) / 100").font(.system(size: 40, weight: .bold, design: .rounded))
                    Text("Score").font(.caption).foregroundStyle(.secondary)
                    ProgressView(value: Double(value), total: 100).tint(status.color)
                }
                .accessibilityElement(children: .combine)
            }
            row("Family", result.family.map { "IPv\($0)" })
            row("Reporting accounts", result.accounts.map { $0.formatted() })
            row("Country", MoreLogic.countryFlag(result.country))
            row("ASN", result.asn.map { "AS\($0)" })
            row("First seen", result.firstSeen)
            row("Last seen", result.lastSeen)
            row("Release", releaseText)
            row("Release valid until", HcFormat.time(result.release?.protectedUntil))
        }
        if let lists = result.lists, !lists.isEmpty { Section("Lists") { MoreChips(values: lists.map(\.rawValue)) } }
        if let kinds = result.kinds, !kinds.isEmpty { Section("Attack kinds") { MoreChips(values: kinds) } }
        if let ports = result.ports, !ports.isEmpty {
            Section {
                ForEach(Array(ports.enumerated()), id: \.offset) { _, port in
                    LabeledContent(port.service ?? "–") { Text(verbatim: port.port.map(String.init) ?? "–").font(.body.monospaced()) }
                }
            } header: {
                Text("Attacked ports")
            } footer: {
                Text("Only ports reported by at least two accounts are shown.")
            }
        }
        if result.status == .notListed, result.listed != true {
            Section { Text("No further details are available for IPs that are not listed.").foregroundStyle(.secondary) }
        }
        if let details = result.details, details.hasPrefix("https://"), let url = URL(string: details) {
            Section {
                Button("Explanation and release request", systemImage: "arrow.up.right.square") { openURL(url) }
            }
        }
    }

    @ViewBuilder private func row(_ label: LocalizedStringKey, _ value: String?) -> some View {
        if let value = value?.nonBlank { LabeledContent(label, value: value) }
    }

    private var releaseText: String? {
        switch result.release?.status {
        case .none?: String(localized: "No release")
        case .inReview?: String(localized: "In review")
        case .released?: String(localized: "Released")
        case .allowlisted?: String(localized: "Allowlisted")
        case .rejected?: String(localized: "Rejected")
        default: nil
        }
    }
}
