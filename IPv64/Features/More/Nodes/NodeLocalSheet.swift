import SwiftUI

/// Direct access sheet (spec 04 §3), presented via router.sheet = .directAccess(nodeId:).
/// STUB – replace this file's contents (keep the type name and init parameters).
struct NodeLocalSheet: View {
    /// `nil` = connect a new node.
    let nodeId: String?

    var body: some View {
        ContentUnavailableView("Not yet ported", systemImage: "hammer")
    }
}
