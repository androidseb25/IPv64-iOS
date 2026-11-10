import SwiftUI

/// Root of the CDN slot: Proxy64 when a connected node has the proxy module, else CDN64 (spec 03 §0).
struct CdnRootView: View {
    @Environment(ConnectedNodes.self) private var nodes

    var body: some View {
        if nodes.proxyActive {
            ProxyView()
        } else {
            CdnView()
        }
    }
}
