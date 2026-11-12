import SwiftUI
import IPv64

/// Core parameters of a check type, in their own section (none for http, icmp, cert, whois).
struct HealthcheckEssentialSection: View {
    @Binding var s: ParamsState
    let type: HC2CheckType
    var error: String?

    private var header: LocalizedStringKey? {
        switch type {
        case .keyword: "Keyword"
        case .json: "JSON rules"
        case .dns: "DNS"
        case .tcp, .port: "Port"
        case .push: "Schedule"
        default: nil
        }
    }

    private var hint: LocalizedStringKey? {
        switch type {
        case .tcp, .port: "Or use host:port as target"
        case .push: "Expected interval is the time between two pushes; the grace period is extra time before the check goes down."
        case .json: s.jsonRules.count > 1 ? "Otherwise all rules must match" : nil
        default: nil
        }
    }

    var body: some View {
        if type.hasEssentialParams, let header {
            Section {
                switch type {
                case .keyword:
                    TextField("Keyword", text: $s.keyword).textInputAutocapitalization(.never).autocorrectionDisabled()
                case .json:
                    JsonRulesEditor(s: $s)
                case .dns:
                    Picker("Record type", selection: $s.recordType) {
                        ForEach(dnsRecordTypes, id: \.self) { Text(verbatim: $0.rawValue).tag($0) }
                    }
                case .tcp:
                    HcFieldRow(label: "Port", text: $s.port, kind: .number, prompt: "443")
                case .port:
                    HcFieldRow(label: "Port", text: $s.port, kind: .number, prompt: "443")
                    Picker("Expected state", selection: $s.expect) {
                        Text("Open").tag("open")
                        Text("Closed").tag("closed")
                    }
                    .pickerStyle(.segmented)
                case .push:
                    HcDurationPicker(label: "Expected interval", value: $s.periodValue, unit: $s.periodUnit,
                                     presets: [60, 300, 900, 1800, 3600, 21_600, 86_400])
                    HcDurationPicker(label: "Grace period", value: $s.graceValue, unit: $s.graceUnit,
                                     presets: [30, 60, 300, 900, 3600])
                default:
                    EmptyView()
                }
            } header: {
                Text(header)
            } footer: {
                HcFooter(hint: hint, error: error)
            }
        }
    }
}

/// Fine options of a check type (rows inside the "Advanced" section).
struct HealthcheckAdvancedParams: View {
    @Binding var s: ParamsState
    let type: HC2CheckType
    let ini: ParamsState
    let editing: Bool
    /// `false` = runs on a node (DNS `public_ip` allowed).
    let online: Bool

    var body: some View {
        switch type {
        case .http, .keyword, .json: http
        case .dns: dns
        case .icmp:
            HcStepperRow(label: "Packets", text: $s.count, range: 1...20)
            HcFieldRow(label: "Max packet loss", text: $s.maxLossPercent, kind: .number, prompt: "Default", unit: "%")
            HcFieldRow(label: "Max latency (0 = off)", text: $s.maxLatencyMs, kind: .number, prompt: "Default", unit: "ms")
        case .tcp:
            HcFieldRow(label: "Data to send", text: $s.send, prompt: "Optional")
            HcFieldRow(label: "Expected response start", text: $s.expect, prompt: "Optional")
            Toggle("Use TLS", isOn: $s.tls)
        case .cert:
            HcFieldRow(label: "Port", text: $s.port, kind: .number, prompt: "443")
            HcFieldRow(label: "Minimum remaining days", text: $s.minDays, kind: .number, prompt: "Default", unit: "days")
            HcFieldRow(label: "Server name (SNI)", text: $s.serverName, prompt: "Optional")
            Toggle("Skip chain validation", isOn: $s.skipChain)
            Toggle("Skip hostname validation", isOn: $s.skipHostname)
        default:
            EmptyView()
        }
    }

    // MARK: HTTP / keyword / JSON

    private var methods: [String] { httpMethods.contains(s.method) ? httpMethods : httpMethods + [s.method] }

    @ViewBuilder private var http: some View {
        Picker("Method", selection: $s.method) {
            ForEach(methods, id: \.self) { Text(verbatim: $0).tag($0) }
        }
        HcFieldRow(label: "Accepted status codes", text: $s.acceptStatus, prompt: "200-299,301")
        if type == .keyword {
            Toggle("Keyword must be absent", isOn: $s.keywordAbsent)
        }
        Toggle("Follow redirects", isOn: $s.followRedirects)
        if s.followRedirects {
            HcFieldRow(label: "Max redirects", text: $s.maxRedirects, kind: .number, prompt: "Default")
        }
        HcFieldRow(label: "Basic auth user", text: $s.basicUser, prompt: "Optional")
        HcFieldRow(label: "Basic auth password", text: $s.basicPassword, kind: .secure,
                   prompt: editing && ini.basicUser.nonBlank != nil ? "Unchanged" : "Optional")
        HeadersEditor(s: $s, ini: ini, editing: editing)
        HcMultilineField(placeholder: "Request body", text: $s.body)
        Toggle("Ignore certificate errors", isOn: $s.insecureTls)
        HcFieldRow(label: "Fail if certificate expires within", text: $s.certMinDays, kind: .number,
                   prompt: "Off", unit: "days")
    }

    // MARK: DNS

    private var expectOptions: [String] {
        var list = ["any", "contains", "equals", "regex", "nxdomain"]
        if !online || s.expect == "public_ip" { list.append("public_ip") }
        return list
    }

    @ViewBuilder private var dns: some View {
        Picker("Resolver", selection: $s.resolver) {
            Text("System").tag(HC2DNSResolver.system)
            Text("Server").tag(HC2DNSResolver.server)
            Text("Authoritative").tag(HC2DNSResolver.authoritative)
        }
        if s.resolver == .server {
            HcFieldRow(label: "DNS server", text: $s.server, kind: .url, prompt: "1.1.1.1")
        }
        Picker("Expected answer", selection: $s.expect) {
            ForEach(expectOptions, id: \.self) { Text(verbatim: $0).tag($0) }
        }
        if s.expect == "contains" || s.expect == "equals" {
            HcMultilineField(placeholder: "Expected values, one per line", text: $s.values)
        } else if s.expect == "regex" {
            HcMultilineField(placeholder: "Pattern", text: $s.values)
        }
        Toggle("Require DNSSEC", isOn: $s.dnssec)
        HcFieldRow(label: "Minimum TTL (0 = any)", text: $s.minTtl, kind: .number, prompt: "Default", unit: "s")
    }
}
