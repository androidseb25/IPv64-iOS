//
//  HealthProvider.swift
//  IPv64WidgetExtension
//
//  Created by Sebastian Rank on 07.11.25.
//

import Foundation
import WidgetKit
import AppIntents
import OSLog

struct HealthEntry: TimelineEntry {
    let date: Date
    let configuration: HealthchecksIntent
    let items: [HealthCheckEntity]
    var updatedAt: Date? = nil
    var isStale: Bool = false
}

struct HealthProvider: AppIntentTimelineProvider {
    typealias Entry = HealthEntry
    typealias I = HealthchecksIntent

    let refreshMinutes: Int = 15

    /// Slots the layout of a family shows (as the former per-size widgets).
    static func slots(_ family: WidgetFamily) -> Int {
        switch family {
        case .systemLarge: 10
        case .systemMedium: 4
        default: 2
        }
    }

    /// Picked checks of the first `slots` slots, without empty ones.
    private func extract(_ i: I, _ family: WidgetFamily) -> [HealthCheckEntity] {
        [i.hc1, i.hc2, i.hc3, i.hc4, i.hc5, i.hc6, i.hc7, i.hc8, i.hc9, i.hc10]
            .prefix(Self.slots(family))
            .compactMap { value in
                guard let value, value.id != HealthCheckEntity.noneID else { return nil }
                return value
            }
    }

    func placeholder(in context: Context) -> Entry {
        .init(date: .now, configuration: I(), items: Array(HealthCheckEntity.sampleList.prefix(Self.slots(context.family))))
    }

    func snapshot(for configuration: I, in context: Context) async -> Entry {
        let selected = extract(configuration, context.family)
        Logger(subsystem: "net.ipv64.widget", category: "configuration").notice("Snapshot family=\(String(describing: context.family), privacy: .public) selected=\(selected.count)")
        return .init(date: .now, configuration: configuration, items: selected)
    }

    func timeline(for configuration: I, in context: Context) async -> Timeline<Entry> {
        let selected = extract(configuration, context.family)
        Logger(subsystem: "net.ipv64.widget", category: "configuration").notice("Timeline family=\(String(describing: context.family), privacy: .public) selected=\(selected.count)")
        // An empty configuration is an intentional empty widget. Returning a
        // fresh entry immediately prevents WidgetKit from keeping the prior
        // selection while a cache or network request is running.
        guard !selected.isEmpty else {
            return Timeline(entries: [Entry(date: .now, configuration: configuration, items: [])], policy: .never)
        }

        guard let snapshot = await HealthCheckCache.shared.fetchOrCached() else {
            // Configuration entities can outlive their account; do not show their old status as current.
            let unavailable = selected.map { HealthCheckEntity(id: $0.id, name: $0.name, states: []) }
            let entry = Entry(date: .now, configuration: configuration, items: unavailable, isStale: true)
            return Timeline(entries: [entry], policy: .after(nextRefresh()))
        }

        let recent = await ApiServiceWidget.fetchRecentStates(tokens: selected.map(\.id))
        let byID = Dictionary(snapshot.checks.map {
            ($0.token, HealthCheckEntity(id: $0.token, name: $0.name, states: recent[$0.token] ?? $0.states))
        }, uniquingKeysWith: { first, _ in first })
        // Preserve every slot, including its own fallback when that check is unavailable.
        let items = selected.map { byID[$0.id] ?? HealthCheckEntity(id: $0.id, name: $0.name, states: []) }
        let hasMissingCheck = selected.contains { byID[$0.id] == nil }
        let entry = Entry(date: .now, configuration: configuration, items: items,
                          updatedAt: snapshot.updatedAt, isStale: snapshot.isStale || hasMissingCheck)
        return Timeline(entries: [entry], policy: .after(nextRefresh()))
    }

    private func nextRefresh() -> Date {
        .now.addingTimeInterval(TimeInterval(refreshMinutes * 60))
    }
}
