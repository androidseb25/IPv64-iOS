//
//  HealthcheckProvider.swift
//  IPv64WidgetExtension
//
//  Created by Sebastian Rank on 05.11.25.
//

import Foundation
import WidgetKit
import AppIntents
import SwiftyBeaver

struct HealthEntry<I: WidgetConfigurationIntent>: TimelineEntry {
    let date: Date
    let configuration: I
    let items: [HealthCheckEntity]
}

struct HealthProvider<I: WidgetConfigurationIntent>: AppIntentTimelineProvider {
    
    var api = ApiServiceWidget()
    let logger = iLogger.shared
    
    typealias Entry = HealthEntry<I>
    
    /// Wie extrahieren wir die Auswahl aus dem Intent? (von außen injiziert)
    let extract: (I) -> [HealthCheckEntity]
    let refreshMinutes: Int = 15
    
    func placeholder(in context: Context) -> Entry {
        iLogger.log.info("\(String(describing: I.self)) placeholdered")
        return .init(date: .now, configuration: I(), items: sample(for: I.self))
    }
    
    func snapshot(for configuration: I, in context: Context) async -> Entry {
        iLogger.log.info("\(String(describing: I.self)) snapshoted")
        return .init(date: .now, configuration: configuration, items: extract(configuration))
    }
    
    func timeline(for configuration: I, in context: Context) async -> Timeline<Entry> {
        iLogger.log.info("\(String(describing: I.self)) timeline updated")
        
        // 1) Ausgewählte IDs in Slot-Reihenfolge
        let selected = extract(configuration)                  // [HealthCheckEntity] aus den Slots
        let selectedIDs = selected.map(\.id)                   // Reihenfolge beibehalten
        let idSet = Set(selectedIDs)                           // für schnelles Lookup
        
        // 2) Alle Daten (cached/TTL) holen und auf IDs filtern
        guard let res = await fetchOrCached() else {
            iLogger.log.info("Timeline: Guardian returned nil")
            let entry = Entry(date: .now, configuration: configuration, items: selected) // Fallback
            return Timeline(entries: [entry], policy: .after(nextRefresh()))
        }
        
        // 3) Map für schnellen Zugriff und stabile Slot-Reihenfolge
        let all = mapAll(res)                                  // [HealthCheckEntity] (voll)
        iLogger.log.info("Timeline: \(all.count) entries")
        let byId = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
        
        iLogger.log.info("Timeline: \(byId.keys) dict")
        
        // 4) Nur die gewählten in Slot-Reihenfolge – mit Fallback auf den Slot-Wert
        let items = selectedIDs.compactMap { byId[$0] ?? selected.first(where: { $0.id == $0.id }) }
        
        iLogger.log.info("Timeline: selected \(items.count) count")
        
        let entry = Entry(date: .now, configuration: configuration, items: items)
        return Timeline(entries: [entry], policy: .after(nextRefresh()))
    }
    
    private func nextRefresh(_ minutes: Int = 15) -> Date {
        Calendar.current.date(byAdding: .minute, value: minutes, to: .now) ?? .now.addingTimeInterval(900)
    }
    
    private func sample<T>(for _: T.Type) -> [HealthCheckEntity] {
        HealthCheckEntity.sampleList
    }
    
    private func mapAll(_ res: HealthCheckResult) -> [HealthCheckEntity] {
        res.domain.sortedWidget(by: \.name).map { HealthCheckEntity(id: $0.healthtoken, name: $0.name, events: $0.events) }
    }
    
    // Gemeinsamer Fetch mit Cache-Nutzung
    private func fetchOrCached() async -> HealthCheckResult? {
//        if let c = await HealthCheckCache.shared.getCached() { return c }
        _ = UserStorageWidget.shared
        if let fresh = await api.GetHealthchecks() {
            if (fresh.status.contains("200")) {
                Task { @MainActor in
                    iLogger.log.info("Timeline: set new data: \(fresh.domain.count)")
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
}
