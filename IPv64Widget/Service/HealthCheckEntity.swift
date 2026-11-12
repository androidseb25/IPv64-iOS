//
//  HealthCheckEntity.swift
//  IPv64WidgetExtension
//
//  Created by Sebastian Rank on 07.11.25.
//

import Foundation
import AppIntents
import SwiftUI
import WidgetKit
import OSLog

struct HealthCheckEntity: AppEntity, Identifiable, Hashable {
    static let noneID = "__ipv64_none__"
    static let none = HealthCheckEntity(id: noneID, name: "Keine Auswahl", states: [])

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Healthcheck")
    static var defaultQuery = HealthCheckQuery()
    
    var id: String
    var name: String
    var states: [String]
    
    static var defaultDisplayRepresentation: DisplayRepresentation {
        .init(title: "No entry")
    }
    
    var displayRepresentation: DisplayRepresentation {
        .init(title: id == Self.noneID ? "Keine Auswahl" : "\(name)")
    }
    
    static let sampleList: [HealthCheckEntity] = (1...10).map { i in
        HealthCheckEntity(id: "\(i)", name: i == 1 ? "API" : "DB\(i)",
                          states: ["up", "down", "degraded", "up", "paused", "up", "up", "down", "up", "up", "pending", "up"])
    }
}

// MARK: - Shared, account-scoped cache

nonisolated struct HealthCheckSnapshot: Sendable {
    let checks: [WidgetCheck]
    let updatedAt: Date
    let isStale: Bool
}

public actor HealthCheckCache {
    public static let shared = HealthCheckCache()

    private let ttl: TimeInterval = 60 * 5
    private var payload: PersistedPayload?
    private var loadedRevision: String?
    private var loadedAccount: String?
    private var inFlight: (id: UUID, account: String, task: Task<[WidgetCheck]?, Never>)?

    private typealias PersistedPayload = WidgetHealthCachePayload

    /// One shared request serves simultaneous widget sizes and intent queries.
    func fetchOrCached() async -> HealthCheckSnapshot? {
        let defaults = UserDefaults(suiteName: WidgetHealthCacheStore.suiteName)
        let revision = defaults?.string(forKey: WidgetHealthCacheStore.revisionKey) ?? "initial"
        let account = Self.accountFingerprint()
        if loadedRevision != revision || loadedAccount != account {
            invalidateMemory()
            loadedRevision = revision
            loadedAccount = account
            if let data = defaults?.data(forKey: WidgetHealthCacheStore.cacheKey),
               let stored = try? JSONDecoder().decode(PersistedPayload.self, from: data),
               account == nil || stored.account == account {
                payload = stored
            }
        }
        // The old payload used asymmetric API encoding and cannot be reliably restored.
        defaults?.removeObject(forKey: "HealthCheckCache_Data_v1")

        if let payload, account == nil {
            return snapshot(payload, isStale: true)
        }
        guard let account else { return nil }
        if let payload, Date().timeIntervalSince(payload.updatedAt) < ttl {
            return snapshot(payload, isStale: false)
        }

        let request: (id: UUID, account: String, task: Task<[WidgetCheck]?, Never>)
        if let existing = inFlight, existing.account == account {
            request = existing
        } else {
            let task = Task { await ApiServiceWidget.fetchChecks() }
            request = (UUID(), account, task)
            inFlight = request
        }
        let response = await request.task.value

        // Account changes and manual refreshes may occur while the actor is suspended.
        guard !Task.isCancelled, !request.task.isCancelled,
              Self.accountFingerprint() == account,
              loadedRevision == revision,
              (defaults?.string(forKey: WidgetHealthCacheStore.revisionKey) ?? "initial") == revision else { return nil }

        if inFlight?.id == request.id {
            inFlight = nil
            if let response {
                let fresh = PersistedPayload(account: account, checks: response, updatedAt: .now)
                payload = fresh
                if let data = try? JSONEncoder().encode(fresh) {
                    defaults?.set(data, forKey: WidgetHealthCacheStore.cacheKey)
                }
            }
        }
        guard let payload, payload.account == account else { return nil }
        return snapshot(payload, isStale: Date().timeIntervalSince(payload.updatedAt) >= ttl)
    }

    public func clear() {
        invalidateMemory()
        let defaults = UserDefaults(suiteName: WidgetHealthCacheStore.suiteName)
        let revision = UUID().uuidString
        loadedRevision = revision
        defaults?.set(revision, forKey: WidgetHealthCacheStore.revisionKey)
        defaults?.removeObject(forKey: WidgetHealthCacheStore.cacheKey)
        defaults?.removeObject(forKey: "HealthCheckCache_Data_v1")
    }

    private func invalidateMemory() {
        inFlight?.task.cancel()
        inFlight = nil
        payload = nil
        loadedAccount = nil
    }

    private func snapshot(_ payload: PersistedPayload, isStale: Bool) -> HealthCheckSnapshot {
        HealthCheckSnapshot(checks: payload.checks, updatedAt: payload.updatedAt, isStale: isStale)
    }

    private static func accountFingerprint() -> String? { WidgetHealthCacheStore.accountFingerprint() }
}

struct ClearHealthCheckCacheIntent: AppIntent {
    static var title: LocalizedStringResource = "Clear Widget Cache"
    
    func perform() async throws -> some IntentResult {
        await HealthCheckCache.shared.clear()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}


struct HealthCheckQuery: EntityQuery {
    
    private func fetchOrCached() async -> HealthCheckSnapshot? {
        await HealthCheckCache.shared.fetchOrCached()
    }

    private func mapAll(_ snapshot: HealthCheckSnapshot) -> [HealthCheckEntity] {
        // Keep real checks first. WidgetKit uses the first suggested entity as
        // the initial value for an unconfigured slot; putting the empty
        // sentinel first would make every new or reloaded widget appear empty.
        let checks = snapshot.checks.sortedWidget(by: \.name).map {
            HealthCheckEntity(id: $0.token, name: $0.name, states: $0.states)
        }
        return checks + [HealthCheckEntity.none]
    }

    // MARK: - EntityQuery
    
    func entities(for identifiers: [String]) async throws -> [HealthCheckEntity] {
        Logger(subsystem: "net.ipv64.widget", category: "query").notice("Resolving entities count=\(identifiers.count) empty=\(identifiers.filter { $0 == HealthCheckEntity.noneID }.count)")
        guard let res = await fetchOrCached() else {
            // Keep an existing widget configuration resolvable even when the
            // cache/API is temporarily unavailable. The timeline provider can
            // refresh the values later without losing the selected IDs.
            return identifiers.compactMap { id in
                id == HealthCheckEntity.noneID
                    ? HealthCheckEntity.none
                    : HealthCheckEntity(id: id, name: id, states: [])
            }
        }
        let set = Set(identifiers)
        let filtered = res.checks.filter { set.contains($0.token) }
        Logger(subsystem: "net.ipv64.widget", category: "query").notice("Available checks=\(res.checks.count) matched=\(filtered.count)")
        var result = filtered.map { HealthCheckEntity(id: $0.token, name: $0.name, states: $0.states) }
        if set.contains(HealthCheckEntity.noneID) { result.insert(.none, at: 0) }
        return result
    }
    
    func suggestedEntities() async throws -> [HealthCheckEntity] {
        guard let res = await fetchOrCached() else { return [.none] }
        return mapAll(res)
    }
    
    func entities(matching string: String) async throws -> [HealthCheckEntity] {
        guard let res = await fetchOrCached() else {
            return HealthCheckEntity.none.name.localizedCaseInsensitiveContains(string) ? [.none] : []
        }
        let all = mapAll(res)
        guard !string.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(string) }
    }
    
    // --- Small: intent-spezifische Overloads (ausblenden bereits gewählter) ---
    func suggestedEntities(for intent: SmallHealthchecksIntent) async throws -> [HealthCheckEntity] {
        guard let res = await fetchOrCached() else { return [.none] }
        let selected = Set([intent.hc1?.id, intent.hc2?.id].compactMap { $0 })
        return mapAll(res).filteringOut(ids: selected)
    }
    
    func entities(matching string: String, for intent: SmallHealthchecksIntent) async throws -> [HealthCheckEntity] {
        guard let res = await fetchOrCached() else {
            return HealthCheckEntity.none.name.localizedCaseInsensitiveContains(string) ? [.none] : []
        }
        let selected = Set([intent.hc1?.id, intent.hc2?.id].compactMap { $0 })
        let all = mapAll(res).filteringOut(ids: selected)
        guard !string.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(string) }
    }
}

extension Array where Element == HealthCheckEntity {
    nonisolated func filteringOut(ids: Set<String>) -> [HealthCheckEntity] {
        filter { $0.id == HealthCheckEntity.noneID || !ids.contains($0.id) }
    }
}

extension HealthCheckQuery {
    // Medium
    func suggestedEntities(for intent: MediumHealthchecksIntent) async throws -> [HealthCheckEntity] {
        guard let res = await fetchOrCached() else { return [.none] }
        let selected = Set([intent.hc1?.id, intent.hc2?.id, intent.hc3?.id, intent.hc4?.id].compactMap { $0 })
        return mapAll(res).filteringOut(ids: selected)
    }
    
    func entities(matching string: String, for intent: MediumHealthchecksIntent) async throws -> [HealthCheckEntity] {
        guard let res = await fetchOrCached() else {
            return HealthCheckEntity.none.name.localizedCaseInsensitiveContains(string) ? [.none] : []
        }
        let selected = Set([intent.hc1?.id, intent.hc2?.id, intent.hc3?.id, intent.hc4?.id].compactMap { $0 })
        let all = mapAll(res).filteringOut(ids: selected)
        guard !string.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(string) }
    }
    
    // Large
    func suggestedEntities(for intent: LargeHealthchecksIntent) async throws -> [HealthCheckEntity] {
        guard let res = await fetchOrCached() else { return [.none] }
        let selected = Set([intent.hc1?.id, intent.hc2?.id, intent.hc3?.id, intent.hc4?.id, intent.hc5?.id, intent.hc6?.id, intent.hc7?.id, intent.hc8?.id, intent.hc9?.id, intent.hc10?.id].compactMap { $0 })
        return mapAll(res).filteringOut(ids: selected)
    }
    
    func entities(matching string: String, for intent: LargeHealthchecksIntent) async throws -> [HealthCheckEntity] {
        guard let res = await fetchOrCached() else {
            return HealthCheckEntity.none.name.localizedCaseInsensitiveContains(string) ? [.none] : []
        }
        let selected = Set([intent.hc1?.id, intent.hc2?.id, intent.hc3?.id, intent.hc4?.id, intent.hc5?.id, intent.hc6?.id, intent.hc7?.id, intent.hc8?.id, intent.hc9?.id, intent.hc10?.id].compactMap { $0 })
        let all = mapAll(res).filteringOut(ids: selected)
        guard !string.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(string) }
    }
}


extension Sequence {
    func sortedWidget(by keyPath: KeyPath<Element, String>) -> [Element] {
        sorted { ($0[keyPath: keyPath]).lowercased() < ($1[keyPath: keyPath]).lowercased() }
    }
}
