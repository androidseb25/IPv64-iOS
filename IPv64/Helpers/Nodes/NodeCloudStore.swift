import Foundation
import CloudKit
import CryptoKit
#if os(iOS)
import SwiftyBeaver
#endif

/// Direct node access mirrored to the user's private CloudKit database, so the Apple TV app can offer it:
/// tvOS never receives iCloud Keychain items (`NodeSyncStore`). One record per node in the zone `Nodes`,
/// record name `<accountId>.<nodeId>`; the API key is an encrypted field (end-to-end encrypted).
/// The iPhone app writes (same "Sync with iCloud" setting and account scope as `NodeSyncStore`), the TV app reads.
nonisolated enum NodeCloudStore {
    struct Node: Sendable, Identifiable {
        let nodeId: String
        let account: Int
        let url: String
        let key: String
        let name: String?
        var id: String { "\(account).\(nodeId)" }
    }

    private static let recordType = "NodeAccess"
    private static let zoneID = CKRecordZone.ID(zoneName: "Nodes")
    private static var database: CKDatabase { CKContainer(identifier: AppConfig.cloudContainer).privateCloudDatabase }

    /// All mirrored nodes; empty when the iPhone app never mirrored any.
    static func fetchAll() async throws -> [Node] {
        var nodes: [String: Node] = [:]  // by record name: a record changed while paging comes twice
        var token: CKServerChangeToken?
        var more = true
        do {
            while more {
                let changes = try await database.recordZoneChanges(inZoneWith: zoneID, since: token)
                for (_, result) in changes.modificationResultsByID {
                    guard let record = try? result.get().record,
                          let url = record["url"] as? String, let key = record.encryptedValues["key"] as? String,
                          case let parts = record.recordID.recordName.split(separator: ".", maxSplits: 1), parts.count == 2,
                          let account = Int(parts[0])
                    else { continue }
                    let node = Node(nodeId: String(parts[1]), account: account, url: url, key: key, name: record["name"] as? String)
                    nodes[node.id] = node
                }
                token = changes.changeToken
                more = changes.moreComing
            }
        } catch let error as CKError where error.code == .zoneNotFound {
            return []
        }
        return nodes.values.sorted { ($0.name ?? $0.url).localizedStandardCompare($1.name ?? $1.url) == .orderedAscending }
    }

    #if os(iOS)
    /// App-group key of the fingerprint of the last mirrored set (skips uploads when nothing changed).
    /// Debug builds use the Development database, release builds Production: separate fingerprints.
    #if DEBUG
    private static let fingerprintKey = "NODE64_CLOUDKIT_FINGERPRINT_DEV"
    #else
    private static let fingerprintKey = "NODE64_CLOUDKIT_FINGERPRINT"
    #endif
    private static var defaults: UserDefaults? { UserDefaults(suiteName: AppConfig.appGroup) }
    /// Writes run one after another, so a delete can never be overtaken by an older upload of the same node.
    @MainActor private static var tail: Task<Void, Never>?

    /// Uploads the account's full set `nodes` (when it differs from the last upload) and deletes `removed` node ids.
    @MainActor static func mirror(_ nodes: [Node], removed: [String] = [], account: Int) {
        let fingerprint = SHA256.hash(data: Data(nodes.sorted { $0.id < $1.id }
            .map { "\($0.id)|\($0.url)|\($0.key)|\($0.name ?? "")" }.joined(separator: "\n").utf8))
            .map { String(format: "%02x", $0) }.joined()
        let changed = fingerprint != defaults?.string(forKey: fingerprintKey)
        guard changed || !removed.isEmpty else { return }
        enqueue {
            try await write(save: changed ? nodes : [], delete: removed.map { "\(account).\($0)" })
            if changed { defaults?.set(fingerprint, forKey: fingerprintKey) }
        }
    }

    /// "Forget access" on this device: removes the node from the TV list too.
    @MainActor static func delete(_ nodeId: String, account: Int) {
        enqueue { try await write(save: [], delete: ["\(account).\(nodeId)"]) }
    }

    @MainActor private static func enqueue(_ operation: @escaping @MainActor () async throws -> Void) {
        let previous = tail
        tail = Task { @MainActor in
            await previous?.value
            do { try await operation() } catch {
                iLogger.log.warning("CloudKit node mirror failed: \(error.localizedDescription)")
            }
        }
    }

    private static func write(save nodes: [Node], delete names: [String]) async throws {
        _ = try await database.modifyRecordZones(saving: [CKRecordZone(zoneID: zoneID)], deleting: [])
        let records = nodes.map { node in
            let record = CKRecord(recordType: recordType, recordID: CKRecord.ID(recordName: node.id, zoneID: zoneID))
            record["url"] = node.url
            record["name"] = node.name
            record.encryptedValues["key"] = node.key
            return record
        }
        let ids = names.map { CKRecord.ID(recordName: $0, zoneID: zoneID) }
        let (saved, deleted) = try await database.modifyRecords(saving: records, deleting: ids, savePolicy: .allKeys, atomically: false)
        for result in saved.values { _ = try result.get() }
        for result in deleted.values {
            if case .failure(let error as CKError) = result, error.code != .unknownItem { throw error }
        }
    }
    #endif
}
