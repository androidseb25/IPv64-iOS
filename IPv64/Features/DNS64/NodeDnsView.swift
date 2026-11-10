import SwiftUI

/// DNS64 tab root / Local DNS of a node (spec 03 §6).
/// STUB – replace this file's contents (keep the type name and init parameters).
struct NodeDnsView: View {
    /// `nil` = DNS64 tab root (node chips); else the local DNS of that node.
    var nodeId: String? = nil

    var body: some View {
        ContentUnavailableView("Not yet ported", systemImage: "hammer")
            .navigationTitle("DNS64")
    }
}
