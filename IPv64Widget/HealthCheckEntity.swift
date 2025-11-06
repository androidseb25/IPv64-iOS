//
//  HealthCheckEntity.swift
//  IPv64WidgetExtension
//
//  Created by Sebastian Rank on 05.11.25.
//

import Foundation
import AppIntents
import SwiftUI
import SwiftyBeaver

struct HealthCheckEntity: AppEntity, Identifiable, Hashable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Healthcheck")
    static var defaultQuery = HealthCheckQuery()
    
    var id: String
    var name: String
    var events: [HealthEvents]
    
    static var defaultDisplayRepresentation: DisplayRepresentation {
        .init(title: "No entry")
    }
    
    var displayRepresentation: DisplayRepresentation {
        .init(title: "\(name)")
    }
    
    static let sampleList: [HealthCheckEntity] = [
        .init(id: "1", name: "API", events: [
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 1, text: "123456789"),
            HealthEvents(event_time: "2023-01-01 01:00:00", status: 4, text: "WARNING: Zeitlimit erreicht, Karenzzeit hat begonnen."),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 3, text: "123456789"),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 0, text: "GET Request von 194.126.177.83 -- Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.3 Safari/605.1.15"),
            HealthEvents(event_time: "2023-01-01 00:00:00", status: 1, text: Optional("Healthcheck Einstellungen übernommen.")),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 4, text: "123456789"),
            HealthEvents(event_time: "2023-01-01 01:00:00", status: 3, text: "WARNING: Zeitlimit erreicht, Karenzzeit hat begonnen."),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 0, text: "123456789"),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 1, text: "GET Request von 194.126.177.83 -- Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.3 Safari/605.1.15"),
            HealthEvents(event_time: "2023-01-01 00:00:00", status: 4, text: Optional("Healthcheck Einstellungen übernommen.")),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 3, text: "123456789")
        ]),
        .init(id: "2", name: "DB2", events: [
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 1, text: "123456789"),
            HealthEvents(event_time: "2023-01-01 01:00:00", status: 4, text: "WARNING: Zeitlimit erreicht, Karenzzeit hat begonnen."),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 3, text: "123456789"),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 0, text: "GET Request von 194.126.177.83 -- Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.3 Safari/605.1.15"),
            HealthEvents(event_time: "2023-01-01 00:00:00", status: 1, text: Optional("Healthcheck Einstellungen übernommen.")),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 4, text: "123456789"),
            HealthEvents(event_time: "2023-01-01 01:00:00", status: 3, text: "WARNING: Zeitlimit erreicht, Karenzzeit hat begonnen."),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 0, text: "123456789"),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 1, text: "GET Request von 194.126.177.83 -- Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.3 Safari/605.1.15"),
            HealthEvents(event_time: "2023-01-01 00:00:00", status: 4, text: Optional("Healthcheck Einstellungen übernommen.")),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 3, text: "123456789")
        ]),
        .init(id: "3", name: "DB3", events: [
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 1, text: "123456789"),
            HealthEvents(event_time: "2023-01-01 01:00:00", status: 4, text: "WARNING: Zeitlimit erreicht, Karenzzeit hat begonnen."),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 3, text: "123456789"),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 0, text: "GET Request von 194.126.177.83 -- Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.3 Safari/605.1.15"),
            HealthEvents(event_time: "2023-01-01 00:00:00", status: 1, text: Optional("Healthcheck Einstellungen übernommen.")),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 4, text: "123456789"),
            HealthEvents(event_time: "2023-01-01 01:00:00", status: 3, text: "WARNING: Zeitlimit erreicht, Karenzzeit hat begonnen."),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 0, text: "123456789"),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 1, text: "GET Request von 194.126.177.83 -- Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.3 Safari/605.1.15"),
            HealthEvents(event_time: "2023-01-01 00:00:00", status: 4, text: Optional("Healthcheck Einstellungen übernommen.")),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 3, text: "123456789")
        ]),
        .init(id: "4", name: "DB4", events: [
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 1, text: "123456789"),
            HealthEvents(event_time: "2023-01-01 01:00:00", status: 4, text: "WARNING: Zeitlimit erreicht, Karenzzeit hat begonnen."),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 3, text: "123456789"),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 0, text: "GET Request von 194.126.177.83 -- Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.3 Safari/605.1.15"),
            HealthEvents(event_time: "2023-01-01 00:00:00", status: 1, text: Optional("Healthcheck Einstellungen übernommen.")),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 4, text: "123456789"),
            HealthEvents(event_time: "2023-01-01 01:00:00", status: 3, text: "WARNING: Zeitlimit erreicht, Karenzzeit hat begonnen."),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 0, text: "123456789"),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 1, text: "GET Request von 194.126.177.83 -- Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.3 Safari/605.1.15"),
            HealthEvents(event_time: "2023-01-01 00:00:00", status: 4, text: Optional("Healthcheck Einstellungen übernommen.")),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 3, text: "123456789")
        ]),
        .init(id: "5", name: "DB5", events: [
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 1, text: "123456789"),
            HealthEvents(event_time: "2023-01-01 01:00:00", status: 4, text: "WARNING: Zeitlimit erreicht, Karenzzeit hat begonnen."),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 3, text: "123456789"),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 0, text: "GET Request von 194.126.177.83 -- Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.3 Safari/605.1.15"),
            HealthEvents(event_time: "2023-01-01 00:00:00", status: 1, text: Optional("Healthcheck Einstellungen übernommen.")),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 4, text: "123456789"),
            HealthEvents(event_time: "2023-01-01 01:00:00", status: 3, text: "WARNING: Zeitlimit erreicht, Karenzzeit hat begonnen."),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 0, text: "123456789"),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 1, text: "GET Request von 194.126.177.83 -- Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.3 Safari/605.1.15"),
            HealthEvents(event_time: "2023-01-01 00:00:00", status: 4, text: Optional("Healthcheck Einstellungen übernommen.")),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 3, text: "123456789")
        ]),
        .init(id: "6", name: "DB6", events: [
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 1, text: "123456789"),
            HealthEvents(event_time: "2023-01-01 01:00:00", status: 4, text: "WARNING: Zeitlimit erreicht, Karenzzeit hat begonnen."),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 3, text: "123456789"),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 0, text: "GET Request von 194.126.177.83 -- Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.3 Safari/605.1.15"),
            HealthEvents(event_time: "2023-01-01 00:00:00", status: 1, text: Optional("Healthcheck Einstellungen übernommen.")),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 4, text: "123456789"),
            HealthEvents(event_time: "2023-01-01 01:00:00", status: 3, text: "WARNING: Zeitlimit erreicht, Karenzzeit hat begonnen."),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 0, text: "123456789"),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 1, text: "GET Request von 194.126.177.83 -- Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.3 Safari/605.1.15"),
            HealthEvents(event_time: "2023-01-01 00:00:00", status: 4, text: Optional("Healthcheck Einstellungen übernommen.")),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 3, text: "123456789")
        ]),
        .init(id: "7", name: "DB7", events: [
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 1, text: "123456789"),
            HealthEvents(event_time: "2023-01-01 01:00:00", status: 4, text: "WARNING: Zeitlimit erreicht, Karenzzeit hat begonnen."),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 3, text: "123456789"),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 0, text: "GET Request von 194.126.177.83 -- Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.3 Safari/605.1.15"),
            HealthEvents(event_time: "2023-01-01 00:00:00", status: 1, text: Optional("Healthcheck Einstellungen übernommen.")),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 4, text: "123456789"),
            HealthEvents(event_time: "2023-01-01 01:00:00", status: 3, text: "WARNING: Zeitlimit erreicht, Karenzzeit hat begonnen."),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 0, text: "123456789"),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 1, text: "GET Request von 194.126.177.83 -- Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.3 Safari/605.1.15"),
            HealthEvents(event_time: "2023-01-01 00:00:00", status: 4, text: Optional("Healthcheck Einstellungen übernommen.")),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 3, text: "123456789")
        ]),
        .init(id: "8", name: "DB8", events: [
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 1, text: "123456789"),
            HealthEvents(event_time: "2023-01-01 01:00:00", status: 4, text: "WARNING: Zeitlimit erreicht, Karenzzeit hat begonnen."),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 3, text: "123456789"),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 0, text: "GET Request von 194.126.177.83 -- Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.3 Safari/605.1.15"),
            HealthEvents(event_time: "2023-01-01 00:00:00", status: 1, text: Optional("Healthcheck Einstellungen übernommen.")),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 4, text: "123456789"),
            HealthEvents(event_time: "2023-01-01 01:00:00", status: 3, text: "WARNING: Zeitlimit erreicht, Karenzzeit hat begonnen."),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 0, text: "123456789"),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 1, text: "GET Request von 194.126.177.83 -- Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.3 Safari/605.1.15"),
            HealthEvents(event_time: "2023-01-01 00:00:00", status: 4, text: Optional("Healthcheck Einstellungen übernommen.")),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 3, text: "123456789")
        ]),
        .init(id: "9", name: "DB9", events: [
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 1, text: "123456789"),
            HealthEvents(event_time: "2023-01-01 01:00:00", status: 4, text: "WARNING: Zeitlimit erreicht, Karenzzeit hat begonnen."),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 3, text: "123456789"),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 0, text: "GET Request von 194.126.177.83 -- Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.3 Safari/605.1.15"),
            HealthEvents(event_time: "2023-01-01 00:00:00", status: 1, text: Optional("Healthcheck Einstellungen übernommen.")),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 4, text: "123456789"),
            HealthEvents(event_time: "2023-01-01 01:00:00", status: 3, text: "WARNING: Zeitlimit erreicht, Karenzzeit hat begonnen."),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 0, text: "123456789"),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 1, text: "GET Request von 194.126.177.83 -- Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.3 Safari/605.1.15"),
            HealthEvents(event_time: "2023-01-01 00:00:00", status: 4, text: Optional("Healthcheck Einstellungen übernommen.")),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 3, text: "123456789")
        ]),
        .init(id: "10", name: "DB10", events: [
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 1, text: "123456789"),
            HealthEvents(event_time: "2023-01-01 01:00:00", status: 4, text: "WARNING: Zeitlimit erreicht, Karenzzeit hat begonnen."),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 3, text: "123456789"),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 0, text: "GET Request von 194.126.177.83 -- Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.3 Safari/605.1.15"),
            HealthEvents(event_time: "2023-01-01 00:00:00", status: 1, text: Optional("Healthcheck Einstellungen übernommen.")),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 4, text: "123456789"),
            HealthEvents(event_time: "2023-01-01 01:00:00", status: 3, text: "WARNING: Zeitlimit erreicht, Karenzzeit hat begonnen."),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 0, text: "123456789"),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 1, text: "GET Request von 194.126.177.83 -- Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.3 Safari/605.1.15"),
            HealthEvents(event_time: "2023-01-01 00:00:00", status: 4, text: Optional("Healthcheck Einstellungen übernommen.")),
            HealthEvents(event_time: "2023-01-01 00:45:00", status: 3, text: "123456789")
        ])
    ]
    
    /**
     
     */
}

// MARK: - Concurrency-sicherer Cache mit TTL
public actor HealthCheckCache {
    public static let shared = HealthCheckCache()

    // MARK: - Properties
    private var result: HealthCheckResult?
    private var lastFetch: Date?
    private let ttl: TimeInterval = 60 * 5
    private let suiteName = "group.ipv64.net"
    private let cacheKey = "HealthCheckCache_Data_v1"

    // MARK: - Init
    init() {
        Task { @MainActor in
            _ = iLogger.shared
        }
        // Beim Start versuchen, persistierten Cache zu laden
        if let payload = Self.loadFromDefaults(suite: suiteName, key: cacheKey) {
            self.result = payload.result
            self.lastFetch = payload.lastFetch
            Task { @MainActor in
                iLogger.log.info("HealthCheckCache loaded from UserDefaults (\(payload.result.domain.count) items)")
            }
        }
    }

    // MARK: - Cache Handling
    func getCached() -> HealthCheckResult? {
        guard let lastFetch else { return nil }

        // Ablauf prüfen
        if Date().timeIntervalSince(lastFetch) < ttl {
            let count = result?.domain.count ?? 0
            Task { @MainActor in
                iLogger.log.info("get data from cache Items: \(count)")
            }
            return result
        }

        // TTL abgelaufen → Cache verwerfen
        clear()
        return nil
    }

    func set(_ res: HealthCheckResult) {
        clear()
        result = res
        lastFetch = Date()
        Self.saveToDefaults(suite: suiteName, key: cacheKey, result: res, lastFetch: lastFetch!)
        Task { @MainActor in
            iLogger.log.info("cache saved (\(res.domain.count) items)")
        }
    }

    public func clear() {
        result = nil
        lastFetch = nil
        Self.removeFromDefaults(suite: suiteName, key: cacheKey)
        Task { @MainActor in
            iLogger.log.info("cache cleared!")
        }
    }

    // MARK: - UserDefaults (App Group) helpers
    private struct PersistedPayload: Codable {
        let result: HealthCheckResult
        let lastFetch: Date
    }

    private static func saveToDefaults(suite: String, key: String, result: HealthCheckResult, lastFetch: Date) {
        let payload = PersistedPayload(result: result, lastFetch: lastFetch)
        guard
            let data = try? JSONEncoder().encode(payload),
            let defaults = UserDefaults(suiteName: suite)
        else { return }
        defaults.set(data, forKey: key)
    }

    private static func loadFromDefaults(suite: String, key: String) -> PersistedPayload? {
        guard
            let defaults = UserDefaults(suiteName: suite),
            let data = defaults.data(forKey: key),
            let payload = try? JSONDecoder().decode(PersistedPayload.self, from: data)
        else { return nil }
        return payload
    }

    private static func removeFromDefaults(suite: String, key: String) {
        UserDefaults(suiteName: suite)?.removeObject(forKey: key)
    }
}

struct ClearHealthCheckCacheIntent: AppIntent {
    static var title: LocalizedStringResource = "Clear Widget Cache"
    
    func perform() async throws -> some IntentResult {
        await HealthCheckCache.shared.clear()
        return .result()
    }
    
    func setApiKey(_ apiKey: String) {
        UserStorageWidget.shared.ApiKey = apiKey
    }
}


struct HealthCheckQuery: EntityQuery {
    
    var api = ApiServiceWidget()
    let logger = iLogger.shared
    
    // Gemeinsamer Fetch mit Cache-Nutzung
    private func fetchOrCached() async -> HealthCheckResult? {
        if let c = await HealthCheckCache.shared.getCached() { return c }
        if let fresh = await api.GetHealthchecks() {
            if (fresh.status.contains("200")) {
                Task { @MainActor in
                    iLogger.log.info("HCQ set new data: \(fresh.domain.count)")
                }
                await HealthCheckCache.shared.set(fresh)
                return fresh
            } else {
                Task { @MainActor in
                    iLogger.log.info("Error while fetching data from API \(fresh.status) \(fresh.info)")
                }
            }
        }
        return nil
    }
    
    // Hilfsmapper
    private func mapAll(_ res: HealthCheckResult) -> [HealthCheckEntity] {
        res.domain.sortedWidget(by: \.name).map { HealthCheckEntity(id: $0.healthtoken, name: $0.name, events: $0.events) }
    }
    
    // MARK: - EntityQuery
    
    func entities(for identifiers: [String]) async throws -> [HealthCheckEntity] {
        guard let res = await fetchOrCached() else { return [] }
        let set = Set(identifiers)
        let filtered = res.domain.filter { set.contains($0.healthtoken) }
        return filtered.map { HealthCheckEntity(id: $0.healthtoken, name: $0.name, events: $0.events) }
    }
    
    func suggestedEntities() async throws -> [HealthCheckEntity] {
        guard let res = await fetchOrCached() else { return [] }
        return mapAll(res)
    }
    
    func entities(matching string: String) async throws -> [HealthCheckEntity] {
        guard let res = await fetchOrCached() else { return [] }
        let all = mapAll(res)
        guard !string.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(string) }
    }
    
    // --- Small: intent-spezifische Overloads (ausblenden bereits gewählter) ---
    func suggestedEntities(for intent: SmallHealthchecksIntent) async throws -> [HealthCheckEntity] {
        guard let res = await fetchOrCached() else { return [] }
        let selected = Set([intent.hc1?.id, intent.hc2?.id].compactMap { $0 })
        return await mapAll(res).filteringOut(ids: selected)
    }
    
    func entities(matching string: String, for intent: SmallHealthchecksIntent) async throws -> [HealthCheckEntity] {
        guard let res = await fetchOrCached() else { return [] }
        let selected = Set([intent.hc1?.id, intent.hc1?.id].compactMap { $0 })
        let all = await mapAll(res).filteringOut(ids: selected)
        guard !string.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(string) }
    }
}

extension Array where Element == HealthCheckEntity {
    func filteringOut(ids: Set<String>) -> [HealthCheckEntity] {
        filter { !ids.contains($0.id) }
    }
}

extension HealthCheckQuery {
    // Medium
    func suggestedEntities(for intent: MediumHealthchecksIntent) async throws -> [HealthCheckEntity] {
        guard let res = await fetchOrCached() else { return [] }
        let selected = Set([intent.hc1?.id, intent.hc2?.id, intent.hc3?.id, intent.hc4?.id].compactMap { $0 })
        return await mapAll(res).filteringOut(ids: selected)
    }
    
    func entities(matching string: String, for intent: MediumHealthchecksIntent) async throws -> [HealthCheckEntity] {
        guard let res = await fetchOrCached() else { return [] }
        let selected = Set([intent.hc1?.id, intent.hc2?.id, intent.hc3?.id, intent.hc4?.id].compactMap { $0 })
        let all = await mapAll(res).filteringOut(ids: selected)
        guard !string.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(string) }
    }
    
    // Large
    func suggestedEntities(for intent: LargeHealthchecksIntent) async throws -> [HealthCheckEntity] {
        guard let res = await fetchOrCached() else { return [] }
        let selected = Set([intent.hc1?.id, intent.hc2?.id, intent.hc3?.id, intent.hc4?.id, intent.hc5?.id, intent.hc6?.id, intent.hc7?.id, intent.hc8?.id, intent.hc9?.id, intent.hc10?.id].compactMap { $0 })
        return await mapAll(res).filteringOut(ids: selected)
    }
    
    func entities(matching string: String, for intent: LargeHealthchecksIntent) async throws -> [HealthCheckEntity] {
        guard let res = await fetchOrCached() else { return [] }
        let selected = Set([intent.hc1?.id, intent.hc2?.id, intent.hc3?.id, intent.hc4?.id, intent.hc5?.id, intent.hc6?.id, intent.hc7?.id, intent.hc8?.id, intent.hc9?.id, intent.hc10?.id].compactMap { $0 })
        let all = await mapAll(res).filteringOut(ids: selected)
        guard !string.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(string) }
    }
}


extension Sequence {
    func sortedWidget(by keyPath: KeyPath<Element, String>) -> [Element] {
        sorted { ($0[keyPath: keyPath]).lowercased() < ($1[keyPath: keyPath]).lowercased() }
    }
}
