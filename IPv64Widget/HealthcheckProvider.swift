//
//  HealthcheckProvider.swift
//  IPv64WidgetExtension
//
//  Created by Sebastian Rank on 05.11.25.
//

import Foundation
import WidgetKit
import AppIntents

struct HealthEntry<I: WidgetConfigurationIntent>: TimelineEntry {
    let date: Date
    let configuration: I
    let items: [HealthCheckEntity]
}

struct HealthProvider<I: WidgetConfigurationIntent>: AppIntentTimelineProvider {
    typealias Entry = HealthEntry<I>
    
    /// Wie extrahieren wir die Auswahl aus dem Intent? (von außen injiziert)
    let extract: (I) -> [HealthCheckEntity]
    let refreshMinutes: Int = 15
    
    func placeholder(in context: Context) -> Entry {
        .init(date: .now, configuration: I(), items: sample(for: I.self))
    }
    
    func snapshot(for configuration: I, in context: Context) async -> Entry {
        .init(date: .now, configuration: configuration, items: extract(configuration))
    }
    
    func timeline(for configuration: I, in context: Context) async -> Timeline<Entry> {
        // Falls du Live-Status nachladen willst:
        // Hier IDs aus `extract(configuration)` verwenden und API pingen.
        let entry = Entry(date: .now, configuration: configuration, items: extract(configuration))
        let next = Calendar.current.date(byAdding: .minute, value: refreshMinutes, to: .now)!
        return Timeline(entries: [entry], policy: .after(next))
    }
    
    private func sample<T>(for _: T.Type) -> [HealthCheckEntity] {
        HealthCheckEntity.sampleList
    }
}
