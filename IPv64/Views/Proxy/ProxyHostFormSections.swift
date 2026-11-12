import SwiftUI
import IPv64

/// Form sections of the proxy host editor: Host, Target or Redirect, Options, Advanced (collapsible).
struct ProxyHostFormSections: View {
    @Binding var form: ProxyHostForm
    /// Inline messages, `nil` until the first Save attempt.
    let errors: ProxyHostForm.Errors?
    let create: Bool
    /// "Default" TLS is only offered while the loaded host has no value (nil would not be sent).
    let offersDefaultTLS: Bool
    let accessLists: [Int: String]
    let certificates: [Int: String]
    @Binding var advanced: Bool

    var body: some View {
        Section {
            if create {
                Picker("Type", selection: $form.kind) {
                    Text("Proxy").tag(Node64.ProxyHostKind.proxy)
                    Text("Redirect").tag(Node64.ProxyHostKind.redirect)
                    Text("TLS passthrough").tag(Node64.ProxyHostKind.passthrough)
                    Text("Status page").tag(Node64.ProxyHostKind.status)
                }
            }
            TextField("Domain names", text: $form.names, axis: .vertical)
                .lineLimit(2...6)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
            if create { Toggle("Enabled", isOn: $form.enabled) }
        } header: {
            Text("Host")
        } footer: {
            HcFooter(hint: "One per line", error: errors?.names)
        }

        if form.isStatus {
            Section {
                LabeledContent("Status page ID") {
                    TextField("1", text: $form.statusPageID).multilineTextAlignment(.trailing).keyboardType(.numberPad)
                }
            } header: {
                Text("Status page")
            } footer: {
                HcFooter(error: errors?.target)
            }
        }
        if form.hasTarget {
            Section {
                if form.isProxy {
                    Picker("Scheme", selection: $form.scheme) {
                        Text("http").tag(Node64.ProxyHostScheme.http)
                        Text("https").tag(Node64.ProxyHostScheme.https)
                    }
                }
                LabeledContent("Target host") {
                    TextField("192.168.1.10", text: $form.host)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                }
                LabeledContent("Target port") {
                    TextField("80", text: $form.port).multilineTextAlignment(.trailing).keyboardType(.numberPad)
                }
            } header: {
                Text("Target")
            } footer: {
                HcFooter(error: errors?.target)
            }
        }
        if form.isRedirect {
            Section {
                LabeledContent("Redirect target") {
                    TextField("example.com/path", text: $form.redirectTarget)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                }
                Picker("Redirect scheme", selection: $form.redirectScheme) {
                    Text("auto").tag(Node64.ProxyHostRedirectScheme.auto)
                    Text("http").tag(Node64.ProxyHostRedirectScheme.http)
                    Text("https").tag(Node64.ProxyHostRedirectScheme.https)
                }
                Picker("Redirect code", selection: $form.redirectCode) {
                    ForEach(ProxyHostForm.redirectCodes, id: \.self) { Text(verbatim: "\($0)").tag($0) }
                }
                Toggle("Preserve path", isOn: $form.preservePath)
            } header: {
                Text("Redirect")
            } footer: {
                HcFooter(hint: "domain[:port][/path]", error: errors?.redirect)
            }
        }
        if form.editable {
            Section("Options") {
                Toggle("Force HTTPS", isOn: $form.forceSSL)
                if form.isProxy {
                    Toggle("WebSockets", isOn: $form.websockets)
                    Toggle("Block exploits", isOn: $form.blockExploits)
                    Toggle("Cache assets", isOn: $form.cacheAssets)
                }
            }
            HcCollapsibleSection(title: "Advanced", isExpanded: $advanced) {
                Toggle("HTTP/2", isOn: $form.http2)
                Toggle("HTTP/3", isOn: $form.http3)
                Toggle("HSTS", isOn: $form.hsts)
                if form.hsts { Toggle("HSTS for subdomains", isOn: $form.hstsSubdomains) }
                Picker("Minimum TLS", selection: $form.minTLS) {
                    if offersDefaultTLS { Text("Default").tag(Node64.ProxyHostMinTLS?.none) }
                    Text("1.2").tag(Node64.ProxyHostMinTLS?.some(.tls12))
                    Text("1.3").tag(Node64.ProxyHostMinTLS?.some(.tls13))
                }
                if form.isProxy { Toggle("Verify target certificate", isOn: $form.verifyTarget) }
                Picker("Access list", selection: $form.accessListID) {
                    Text("None (public)").tag(0)
                    ForEach(accessLists.keys.sorted().filter { $0 != 0 }, id: \.self) { id in
                        Text(verbatim: accessLists[id] ?? "#\(id)").tag(id)
                    }
                }
                Picker("Certificate", selection: $form.certID) {
                    Text("Automatic (matching name)").tag(0)
                    Text("None (HTTP only)").tag(-1)
                    ForEach(certificates.keys.sorted().filter { $0 > 0 }, id: \.self) { id in
                        Text(verbatim: certificates[id] ?? "#\(id)").tag(id)
                    }
                }
            }
        }
    }
}
