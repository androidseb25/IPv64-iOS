import Foundation

/// Every pushed screen of the app (Android `Tab` destinations that are reachable, spec 01 §1.1).
/// Carry identifiers only, never models or secrets. Feature agents edit only their own cases' lines.
enum Route: Hashable {
    // DynDNS (spec 02 A)
    case domainDetail(name: String)
    case domainSettings(name: String)
    case recordEdit(domain: String, recordId: String)

    // Healthchecks (spec 02 B)
    case healthcheckDetail(token: String)
    /// `nil` = new healthcheck.
    case healthcheckForm(token: String?)
    case nodeCheckDetail(nodeId: String, token: String)
    /// `token == nil` = new node healthcheck.
    case nodeCheckEdit(nodeId: String, token: String?)

    // CDN64 / Proxy64 (spec 03 §1–5, §10)
    /// CdnView pushed from the Proxy64 root ("CDN64" row).
    case cdn
    case cdnDetail(token: String)
    case cdnSettings(token: String)
    /// `hostId == nil` = new proxy host.
    case proxyHostEdit(nodeId: String, hostId: Int?)

    // DNS64 / local DNS of a node (spec 03 §6, §8, §9)
    /// NodeDnsView for one node (from the node module screen; no node chips).
    case nodeDns(nodeId: String)
    case nodeDnsLog(nodeId: String)
    case nodeDnsRecords(nodeId: String)

    // More (spec 01 §3.5–3.7, spec 04)
    case account
    case accountDetails
    case accountEdit(accountId: UUID)
    /// LoginView(isFromUser: true) from the Users list.
    case addAccount
    case apiKeys
    case accountLinks
    case nodes
    case nodeDetail(nodeId: String)
    case nodeModule(nodeId: String, module: String)
    case channels
    case channelNew
    case channelEdit(id: Int)
    case pushSetup
    case notificationSettings
    /// `ip` is looked up immediately when given.
    case threatLookup(ip: String?)
    case passwordCheck
    case honeypot
    case logs
    case about
}

/// Sheets that more than one screen opens (presented by the tab container via `router.sheet`).
/// Screen-local sheets stay local (`.sheet(item:)` with a private enum).
enum SheetRoute: Identifiable, Hashable {
    /// Direct node access ("Connect directly" / "Direct access"); `nil` = new node.
    case directAccess(nodeId: String?)

    var id: Self { self }
}
