import SwiftUI
import IPv64

/// Essential (always visible) parameters of a check type (spec 02 B5 non-advanced).
struct HealthcheckEssentialParams: View {
    @Binding var s: ParamsState
    let type: HC2CheckType

    var body: some View {
        switch type {
        case .keyword:
            HcField(label: "Keyword", text: $s.keyword)
        case .json:
            JsonRulesEditor(s: $s)
        case .dns:
            Picker("Record type", selection: $s.recordType) {
                ForEach(dnsRecordTypes, id: \.self) { Text(verbatim: $0.rawValue).tag($0) }
            }
        case .tcp:
            HcField(label: "Port", text: $s.port, kind: .number, footer: "Or use host:port as target")
        case .port:
            HcField(label: "Port", text: $s.port, kind: .number, footer: "Or use host:port as target")
            Picker("Expected state", selection: $s.expect) {
                Text("Open").tag("open")
                Text("Closed").tag("closed")
            }
        case .push:
            HcDurationField(label: "Expected interval", value: $s.periodValue, unit: $s.periodUnit,
                            footer: "Time between two pushes")
            HcDurationField(label: "Grace period", value: $s.graceValue, unit: $s.graceUnit,
                            footer: "Extra time before the check goes down")
        default:
            EmptyView()
        }
    }
}

/// Fine options of a check type (inside "Advanced"; spec 02 B5).
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
            HcField(label: "Packets (1-20)", text: $s.count, kind: .number)
            HcField(label: "Max packet loss (%)", text: $s.maxLossPercent, kind: .number)
            HcField(label: "Max latency (ms)", text: $s.maxLatencyMs, kind: .number, footer: "0 = off")
        case .tcp:
            HcField(label: "Data to send", text: $s.send)
            HcField(label: "Expected response start", text: $s.expect)
            HcToggle(label: "Use TLS", isOn: $s.tls)
        case .cert:
            HcField(label: "Port", text: $s.port, kind: .number, footer: "Default: 443")
            HcField(label: "Minimum remaining days", text: $s.minDays, kind: .number)
            HcField(label: "Server name (SNI)", text: $s.serverName)
            HcToggle(label: "Skip chain validation", isOn: $s.skipChain)
            HcToggle(label: "Skip hostname validation", isOn: $s.skipHostname)
        default:
            EmptyView()
        }
    }

    // MARK: HTTP / keyword / JSON

    private var methods: [String] { httpMethods.contains(s.method) ? httpMethods : httpMethods + [s.method] }

    @ViewBuilder
    private var http: some View {
        Picker("Method", selection: $s.method) {
            ForEach(methods, id: \.self) { Text(verbatim: $0).tag($0) }
        }
        HcField(label: "Accepted status codes", text: $s.acceptStatus, prompt: "200-299,301")
        if type == .keyword {
            HcToggle(label: "Keyword must be absent", isOn: $s.keywordAbsent, footer: "The check fails if the text is found")
        }
        HcToggle(label: "Follow redirects", isOn: $s.followRedirects)
        if s.followRedirects {
            HcField(label: "Max redirects", text: $s.maxRedirects, kind: .number)
        }
        HcField(label: "Basic auth user", text: $s.basicUser)
        HcField(label: "Basic auth password", text: $s.basicPassword, kind: .secure, footer: passwordFooter)
        HeadersEditor(s: $s, ini: ini, editing: editing)
        HcField(label: "Request body", text: $s.body, multiline: true)
        HcToggle(label: "Ignore certificate errors", isOn: $s.insecureTls)
        HcField(label: "Fail if certificate expires within (days)", text: $s.certMinDays, kind: .number,
                footer: "HTTPS only, 0 = off")
    }

    private var passwordFooter: LocalizedStringKey? {
        guard editing else { return nil }
        return ini.basicUser.nonBlank != nil && s.basicPassword.isEmpty
            ? "Re-enter the password if the server requires it; leave empty to keep the current one"
            : "Leave empty to keep the stored password"
    }

    // MARK: DNS

    private var expectOptions: [String] {
        var list = ["any", "contains", "equals", "regex", "nxdomain"]
        if !online || s.expect == "public_ip" { list.append("public_ip") }
        return list
    }

    @ViewBuilder
    private var dns: some View {
        Picker("Resolver", selection: $s.resolver) {
            Text("System").tag(HC2DNSResolver.system)
            Text("Server").tag(HC2DNSResolver.server)
            Text("Authoritative").tag(HC2DNSResolver.authoritative)
        }
        if s.resolver == .server {
            HcField(label: "DNS server", text: $s.server, kind: .url, prompt: "1.1.1.1",
                    footer: "IP address, optionally with port")
        }
        Picker("Expected answer", selection: $s.expect) {
            ForEach(expectOptions, id: \.self) { Text(verbatim: $0).tag($0) }
        }
        if s.expect == "contains" || s.expect == "equals" {
            HcField(label: "Expected values", text: $s.values, footer: "One value per line", multiline: true)
        } else if s.expect == "regex" {
            HcField(label: "Pattern", text: $s.values, multiline: true)
        }
        HcToggle(label: "Require DNSSEC", isOn: $s.dnssec)
        HcField(label: "Minimum TTL (seconds)", text: $s.minTtl, kind: .number, footer: "0 = any")
    }
}

/// Header rows with masked values (eye toggle).
private struct HeadersEditor: View {
    @Binding var s: ParamsState
    let ini: ParamsState
    let editing: Bool
    @State private var showValues = false

    var body: some View {
        HStack {
            Text("Headers").font(.subheadline.weight(.semibold))
            Spacer()
            Button(showValues ? "Hide values" : "Show values", systemImage: showValues ? "eye.slash" : "eye") {
                showValues.toggle()
            }
            .labelStyle(.iconOnly).buttonStyle(.borderless)
        }
        if editing && s.headersNeedReentry(ini) {
            Text("Masked header values can't be sent back; re-enter them when you change headers")
                .font(.caption).foregroundStyle(.secondary)
        }
        ForEach($s.headers) { $row in
            HStack(alignment: .top) {
                VStack {
                    TextField("Name", text: $row.key).textInputAutocapitalization(.never).autocorrectionDisabled()
                    if showValues {
                        TextField("Value", text: $row.value).textInputAutocapitalization(.never).autocorrectionDisabled()
                    } else {
                        SecureField("Value", text: $row.value)
                    }
                }
                Button("Remove header", systemImage: "trash", role: .destructive) {
                    s.headers.removeAll { $0.id == row.id }
                }
                .labelStyle(.iconOnly).buttonStyle(.borderless)
            }
        }
        Button("Add header", systemImage: "plus") { s.headers.append(HeaderRow()) }
    }
}

/// JSON rules (essential for JSON checks).
private struct JsonRulesEditor: View {
    @Binding var s: ParamsState

    var body: some View {
        Text("JSON rules").font(.subheadline.weight(.semibold))
        ForEach($s.jsonRules) { $rule in
            VStack(alignment: .leading) {
                HStack {
                    TextField("Path", text: $rule.path, prompt: Text(verbatim: "data.items[0].status"))
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("Remove rule", systemImage: "trash", role: .destructive) {
                        s.jsonRules.removeAll { $0.id == rule.id }
                    }
                    .labelStyle(.iconOnly).buttonStyle(.borderless)
                }
                Picker("Operator", selection: $rule.op) {
                    ForEach(jsonRuleOperators, id: \.self) { Text(verbatim: $0.rawValue).tag($0) }
                }
                if rule.op.needsValue {
                    TextField("Value", text: $rule.value).textInputAutocapitalization(.never).autocorrectionDisabled()
                }
            }
        }
        if s.jsonRules.count < 10 {
            Button("Add rule", systemImage: "plus") { s.jsonRules.append(JsonRuleRow()) }
        }
        if s.jsonRules.count > 1 {
            HcToggle(label: "Any rule is enough", isOn: $s.jsonAny, footer: "Otherwise all rules must match")
        }
    }
}
