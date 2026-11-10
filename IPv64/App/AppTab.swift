import SwiftUI

/// Bottom tabs (Android `Tabs.tabList`, spec 01 §1.2). `.cdn` is the CDN64 / Proxy64 slot,
/// `.dns64` only exists while a connected node has DNS64 enabled.
enum AppTab: Hashable, CaseIterable {
    case dynDNS, healthchecks, cdn, dns64, more

    func title(proxyActive: Bool) -> LocalizedStringKey {
        switch self {
        case .dynDNS: "DynDNS"
        case .healthchecks: "Healthchecks"
        case .cdn: proxyActive ? "Proxy64" : "CDN64"
        case .dns64: "DNS64"
        case .more: "More"
        }
    }

    func systemImage(proxyActive: Bool) -> String {
        switch self {
        case .dynDNS: "globe"
        case .healthchecks: "waveform.path.ecg"
        case .cdn: proxyActive ? "arrow.left.arrow.right" : "cloud"
        case .dns64: "server.rack"
        case .more: "ellipsis"
        }
    }

    /// Tabs whose root is a list with a detail column (NavigationSplitView); DNS64 is a plain stack.
    var usesSplitView: Bool { self != .dns64 }
}
