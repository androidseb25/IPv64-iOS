//
//  AppIntent.swift
//  IPv64Widget
//
//  Created by Sebastian Rank on 07.11.25.
//

import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Configuration" }
    static var description: IntentDescription { "This is an example widget." }

    // An example configurable parameter.
    @Parameter(title: "Favorite Emoji", default: "😃")
    var favoriteEmoji: String
}

struct SmallHealthchecksIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Small Widget"
    static var description = IntentDescription("Choose up to 2 Healthcheacks for the small widget.")
    @Parameter(title: "HC 1") var hc1: HealthCheckEntity?
    @Parameter(title: "HC 2") var hc2: HealthCheckEntity?
}

struct MediumHealthchecksIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Medium Widget"
    static var description = IntentDescription("Choose up to 4 Healthcheacks for the medium widget.")
    @Parameter(title: "HC 1") var hc1: HealthCheckEntity?
    @Parameter(title: "HC 2") var hc2: HealthCheckEntity?
    @Parameter(title: "HC 3") var hc3: HealthCheckEntity?
    @Parameter(title: "HC 4") var hc4: HealthCheckEntity?
}

struct LargeHealthchecksIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Large Widget"
    static var description = IntentDescription("Choose up to 10 Healthcheacks for the large widget.")
    @Parameter(title: "HC 1") var hc1: HealthCheckEntity?
    @Parameter(title: "HC 2") var hc2: HealthCheckEntity?
    @Parameter(title: "HC 3") var hc3: HealthCheckEntity?
    @Parameter(title: "HC 4") var hc4: HealthCheckEntity?
    @Parameter(title: "HC 5") var hc5: HealthCheckEntity?
    @Parameter(title: "HC 6") var hc6: HealthCheckEntity?
    @Parameter(title: "HC 7") var hc7: HealthCheckEntity?
    @Parameter(title: "HC 8") var hc8: HealthCheckEntity?
    @Parameter(title: "HC 9") var hc9: HealthCheckEntity?
    @Parameter(title: "HC 10") var hc10: HealthCheckEntity?
}
