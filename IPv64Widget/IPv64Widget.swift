//
//  IPv64Widget.swift
//  IPv64Widget
//
//  Created by Sebastian Rank on 07.11.25.
//

import WidgetKit
import SwiftUI

struct HealthcheckSmallWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "HealthcheckSmallWidget",
            intent: SmallHealthchecksIntent.self,
            provider: HealthProvider<SmallHealthchecksIntent>(extract: { i in
                selectedHealthchecks([i.hc1, i.hc2])
            })
        ) { entry in
            HealthcheckWidgetView(items: entry.items, updatedAt: entry.updatedAt, isStale: entry.isStale) // exakt 2 Slots
        }
        .configurationDisplayName("Healthchecks (small)")
        .description("Show up to 2 Healthchecks.")
        .supportedFamilies([.systemSmall])
    }
}

struct HealthcheckMediumWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "HealthcheckMediumWidget",
            intent: MediumHealthchecksIntent.self,
            provider: HealthProvider<MediumHealthchecksIntent>(extract: { i in
                selectedHealthchecks([i.hc1, i.hc2, i.hc3, i.hc4])
            })
        ) { entry in
            HealthcheckWidgetView(items: entry.items, updatedAt: entry.updatedAt, isStale: entry.isStale) // exakt 4 Slots
        }
        .configurationDisplayName("Healthchecks (medium)")
        .description("Show up to 4 Healthchecks.")
        .supportedFamilies([.systemMedium])
    }
}

struct HealthcheckLargeWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "HealthcheckLargeWidget",
            intent: LargeHealthchecksIntent.self,
            provider: HealthProvider<LargeHealthchecksIntent>(extract: { i in
                selectedHealthchecks([i.hc1, i.hc2, i.hc3, i.hc4, i.hc5, i.hc6, i.hc7, i.hc8, i.hc9, i.hc10])
            })
        ) { entry in
            HealthcheckWidgetView(items: entry.items, updatedAt: entry.updatedAt, isStale: entry.isStale) // exakt 10 Slots
        }
        .configurationDisplayName("Healthchecks (large)")
        .description("Show up to 10 Healthchecks.")
        .supportedFamilies([
            .systemLarge
            // , .systemExtraLarge // für macOS hinzufügen, falls gewünscht
        ])
    }
}

private func selectedHealthchecks(_ values: [HealthCheckEntity?]) -> [HealthCheckEntity] {
    values.compactMap { value in
        guard let value, value.id != HealthCheckEntity.noneID else { return nil }
        return value
    }
}

#Preview(as: .systemSmall) {
    HealthcheckSmallWidget()
} timeline: {
    HealthEntry(date: .now, configuration: SmallHealthchecksIntent(), items: HealthCheckEntity.sampleList)
}
