//
//  IPv64Widget.swift
//  IPv64Widget
//
//  Created by Sebastian Rank on 07.11.25.
//

import WidgetKit
import SwiftUI

/// One kind for every size; the layout follows the family (small 2, medium 4, large 10 checks).
struct HealthcheckWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "HealthcheckWidget", intent: HealthchecksIntent.self, provider: HealthProvider()) { entry in
            HealthcheckWidgetView(items: entry.items, updatedAt: entry.updatedAt, isStale: entry.isStale)
        }
        .configurationDisplayName("Healthchecks")
        .description("Show up to 2 (small), 4 (medium) or 10 (large) healthchecks.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemSmall) {
    HealthcheckWidget()
} timeline: {
    HealthEntry(date: .now, configuration: HealthchecksIntent(), items: HealthCheckEntity.sampleList)
}
