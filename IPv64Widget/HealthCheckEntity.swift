//
//  HealthCheckEntity.swift
//  IPv64WidgetExtension
//
//  Created by Sebastian Rank on 05.11.25.
//

import Foundation
import AppIntents

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

import AppIntents

// MARK: - Concurrency-sicherer Cache mit TTL
actor HealthCheckCache {
    static let shared = HealthCheckCache()
    private var result: HealthCheckResult?
    private var lastFetch: Date?
    private let ttl: TimeInterval = 60 * 5

    func getCached() -> HealthCheckResult? {
        if let lastFetch, Date().timeIntervalSince(lastFetch) < ttl { return result }
        return nil
    }
    func set(_ res: HealthCheckResult) { result = res; lastFetch = Date() }
    func clear() { result = nil; lastFetch = nil }
}

struct HealthCheckQuery: EntityQuery {

    // Gemeinsamer Fetch mit Cache-Nutzung
    private func fetchOrCached() async -> HealthCheckResult? {
        if let c = await HealthCheckCache.shared.getCached() { return c }
        let api = ApiServiceWidget()
        if let fresh = await api.GetHealthchecks() {
            await HealthCheckCache.shared.set(fresh)
            return fresh
        }
        return nil
    }

    // Hilfsmapper
    private func mapAll(_ res: HealthCheckResult) -> [HealthCheckEntity] {
        res.domain.map { HealthCheckEntity(id: $0.healthtoken, name: $0.name, events: $0.events) }
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
        return mapAll(res).filteringOut(ids: selected)
    }

    func entities(matching string: String, for intent: SmallHealthchecksIntent) async throws -> [HealthCheckEntity] {
        guard let res = await fetchOrCached() else { return [] }
        let selected = Set([intent.hc1?.id, intent.hc1?.id].compactMap { $0 })
        let all = mapAll(res).filteringOut(ids: selected)
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
        return mapAll(res).filteringOut(ids: selected)
    }

    func entities(matching string: String, for intent: MediumHealthchecksIntent) async throws -> [HealthCheckEntity] {
        guard let res = await fetchOrCached() else { return [] }
        let selected = Set([intent.hc1?.id, intent.hc2?.id, intent.hc3?.id, intent.hc4?.id].compactMap { $0 })
        let all = mapAll(res).filteringOut(ids: selected)
        guard !string.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(string) }
    }

    // Large
    func suggestedEntities(for intent: LargeHealthchecksIntent) async throws -> [HealthCheckEntity] {
        guard let res = await fetchOrCached() else { return [] }
        let selected = Set([intent.hc1?.id, intent.hc2?.id, intent.hc3?.id, intent.hc4?.id, intent.hc5?.id, intent.hc6?.id, intent.hc7?.id, intent.hc8?.id, intent.hc9?.id, intent.hc10?.id].compactMap { $0 })
        return mapAll(res).filteringOut(ids: selected)
    }

    func entities(matching string: String, for intent: LargeHealthchecksIntent) async throws -> [HealthCheckEntity] {
        guard let res = await fetchOrCached() else { return [] }
        let selected = Set([intent.hc1?.id, intent.hc2?.id, intent.hc3?.id, intent.hc4?.id, intent.hc5?.id, intent.hc6?.id, intent.hc7?.id, intent.hc8?.id, intent.hc9?.id, intent.hc10?.id].compactMap { $0 })
        let all = mapAll(res).filteringOut(ids: selected)
        guard !string.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(string) }
    }
}
