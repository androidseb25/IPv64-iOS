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

struct HealthEntry<I: WidgetConfigurationIntent>: TimelineEntry {
    let date: Date
    let configuration: I
    let items: [HealthCheckEntity]
    var updatedAt: Date? = nil
    var isStale: Bool = false
}

struct HealthProvider<I: WidgetConfigurationIntent>: AppIntentTimelineProvider {
    typealias Entry = HealthEntry<I>

    let extract: (I) -> [HealthCheckEntity]
    let refreshMinutes: Int = 15

    func placeholder(in context: Context) -> Entry {
        let count = I.self == LargeHealthchecksIntent.self ? 10
            : I.self == MediumHealthchecksIntent.self ? 4 : 2
        return .init(date: .now, configuration: I(), items: Array(HealthCheckEntity.sampleList.prefix(count)))
    }

    func snapshot(for configuration: I, in context: Context) async -> Entry {
        let selected = extract(configuration)
        Logger(subsystem: "net.ipv64.widget", category: "configuration").notice("Snapshot type=\(String(describing: I.self), privacy: .public) selected=\(selected.count)")
        return .init(date: .now, configuration: configuration, items: selected)
    }

    func timeline(for configuration: I, in context: Context) async -> Timeline<Entry> {
        let selected = extract(configuration)
        Logger(subsystem: "net.ipv64.widget", category: "configuration").notice("Timeline type=\(String(describing: I.self), privacy: .public) selected=\(selected.count)")
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

        let byID = Dictionary(snapshot.checks.map {
            ($0.token, HealthCheckEntity(id: $0.token, name: $0.name, states: $0.states))
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
