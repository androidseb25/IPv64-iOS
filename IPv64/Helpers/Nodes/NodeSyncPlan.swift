import Foundation

/// Pure merge rules of the iCloud node sync (`NodeSyncStore`), kept free of storage so they can be checked alone.
nonisolated enum NodeSyncPlan {
    struct Entry: Codable, Equatable, Sendable {
        var url: String
        var key: String
        var name: String?
        var updatedAt: Date
        /// Deletion marker ("Forget access" on one device): removes the access on the others.
        var deleted: Bool?
    }

    /// Pure merge. Local changes (`dirty`) and access missing in iCloud are pushed; iCloud access that is
    /// missing or different here is imported (skipping ids stored for another account on this device);
    /// local access with a deletion marker is removed unless it was changed here since.
    static func plan(local: [String: Entry], synced: [String: Entry], dirty: Set<String>, otherOwner: Set<String>)
        -> (push: [String], upsert: [String: Entry], remove: [String], inSync: [String]) {
        let push = local.keys.filter { dirty.contains($0) || synced[$0] == nil }.sorted()
        let remove = local.keys.filter { !dirty.contains($0) && synced[$0]?.deleted == true }.sorted()
        let upsert = synced.filter { id, entry in
            guard entry.deleted != true, !dirty.contains(id), !otherOwner.contains(id) else { return false }
            guard let mine = local[id] else { return true }
            return mine.url != entry.url || mine.key != entry.key || (entry.name != nil && mine.name != entry.name)
        }
        let inSync = local.keys.filter { !push.contains($0) && !remove.contains($0) && upsert[$0] == nil }.sorted()
        return (push, upsert, remove, inSync)
    }
}
