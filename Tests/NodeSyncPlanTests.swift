// Run: Tests/run-node-sync-tests.sh — checks the merge rules that decide what the iCloud node sync deletes.
import Foundation

@main
struct NodeSyncPlanTests {
    typealias E = NodeSyncPlan.Entry
    static func e(_ url: String, _ key: String = "k1", deleted: Bool? = nil) -> E {
        E(url: url, key: key, name: nil, updatedAt: .distantPast, deleted: deleted)
    }

    static func main() {
        let tomb = e("", "", deleted: true)
        // New device: cloud entry imported.
        var r = NodeSyncPlan.plan(local: [:], synced: ["a": e("u")], dirty: [], otherOwner: [])
        precondition(r.upsert.keys.sorted() == ["a"] && r.push.isEmpty && r.remove.isEmpty)
        // Existing node never synced: pushed, nothing removed.
        r = NodeSyncPlan.plan(local: ["a": e("u")], synced: [:], dirty: [], otherOwner: [])
        precondition(r.push == ["a"] && r.remove.isEmpty && r.upsert.isEmpty)
        // iCloud Keychain wiped (items missing): re-pushed, never removed.
        r = NodeSyncPlan.plan(local: ["a": e("u"), "b": e("v")], synced: [:], dirty: [], otherOwner: [])
        precondition(r.remove.isEmpty && r.push == ["a", "b"])
        // Forgotten on another device: removed here.
        r = NodeSyncPlan.plan(local: ["a": e("u")], synced: ["a": tomb], dirty: [], otherOwner: [])
        precondition(r.remove == ["a"] && r.push.isEmpty)
        // Re-added here after a forget elsewhere: pushed, not removed.
        r = NodeSyncPlan.plan(local: ["a": e("u")], synced: ["a": tomb], dirty: ["a"], otherOwner: [])
        precondition(r.remove.isEmpty && r.push == ["a"])
        // Key changed here offline: local wins, cloud copy not imported.
        r = NodeSyncPlan.plan(local: ["a": e("u", "new")], synced: ["a": e("u", "old")], dirty: ["a"], otherOwner: [])
        precondition(r.push == ["a"] && r.upsert.isEmpty)
        // Key changed on another device: imported.
        r = NodeSyncPlan.plan(local: ["a": e("u", "old")], synced: ["a": e("u", "new")], dirty: [], otherOwner: [])
        precondition(r.upsert["a"]?.key == "new" && r.push.isEmpty)
        // Identical: only marked as in sync.
        r = NodeSyncPlan.plan(local: ["a": e("u")], synced: ["a": e("u")], dirty: [], otherOwner: [])
        precondition(r.inSync == ["a"] && r.push.isEmpty && r.upsert.isEmpty && r.remove.isEmpty)
        // Deletion marker of a node not stored here: nothing to import.
        r = NodeSyncPlan.plan(local: [:], synced: ["a": tomb], dirty: [], otherOwner: [])
        precondition(r.upsert.isEmpty && r.remove.isEmpty)
        // Node id stored for another account on this device: not taken over.
        r = NodeSyncPlan.plan(local: [:], synced: ["a": e("u")], dirty: [], otherOwner: ["a"])
        precondition(r.upsert.isEmpty)
        print("NodeSyncPlan: all checks passed")
    }
}
