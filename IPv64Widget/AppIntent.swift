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

/// One intent for every size: small shows the first 2 checks, medium 4, large 10.
struct HealthchecksIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Healthchecks"
    static var description = IntentDescription("Choose up to 10 healthchecks: small shows 2, medium 4, large 10.")
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
