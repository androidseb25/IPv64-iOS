//
//  HealthcheckWidget.swift
//  HealthcheckWidget
//
//  Created by Sebastian Rank on 20.01.23.
//

import WidgetKit
import SwiftUI
import Intents

struct Provider: IntentTimelineProvider {
    
    @AppStorage("HealthcheckList") var healthCheckList: String = ""
    
    func placeholder(in context: Context) -> SimpleEntry {
        var count = 2
        
        if #available(iOSApplicationExtension 16.0, *) {
            if context.family == .accessoryRectangular {
                count = 1
            } else if context.family == .systemSmall {
                count = 2
            } else if context.family == .systemMedium {
                count = 4
            } else {
                count = 9
            }
        } else {
            if context.family == .systemSmall {
                count = 2
            } else if context.family == .systemMedium {
                count = 4
            } else {
                count = 9
            }
        }
        let hc = DummyData.HealthcheckListCustom(customCount: count)
        return SimpleEntry(date: Date(), configuration: ConfigurationIntent(), healthcheck: hc)
    }
    
    func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        var count = 2
        if #available(iOSApplicationExtension 16.0, *) {
            if context.family == .accessoryRectangular {
                count = 1
            } else if context.family == .systemSmall {
                count = 2
            } else if context.family == .systemMedium {
                count = 4
            } else {
                count = 9
            }
        } else {
            if context.family == .systemSmall {
                count = 2
            } else if context.family == .systemMedium {
                count = 4
            } else {
                count = 9
            }
        }
        let hc = DummyData.HealthcheckListCustom(customCount: count)
        let entry = SimpleEntry(date: Date(), configuration: configuration, healthcheck: hc)
        completion(entry)
    }
    
    func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        Task {
            let api = NetworkServices()
            let hcd = DummyData.HealthcheckListCustom(customCount: 2)
            let hcr = await api.GetHealthchecks() ?? HealthCheckResult(domain: hcd)
            
            let sorted = hcr.domain.sorted { $0.name > $1.name }
            let shrinkedEventList = Array(sorted)
            if (configuration.healthcheckSymbol1 != nil) {
                let health = shrinkedEventList.first { $0.healthtoken == configuration.healthcheckSymbol1?.identifier }
                if (health == nil) {
                    configuration.healthcheckSymbol1 = nil
                } else {
                    let healthStatus = HealthcheckSymbol(identifier: health!.healthtoken, display: health!.name)
                    healthStatus.events = []
                    health!.events.forEach { e in
                        let event = EventSymbol(identifier: UUID().uuidString, display: e.status!.formatted())
                        healthStatus.events?.append(event)
                    }
                    configuration.healthcheckSymbol1 = healthStatus
                }
            }
            if (configuration.healthcheckSymbol2 != nil) {
                let health = shrinkedEventList.first { $0.healthtoken == configuration.healthcheckSymbol2?.identifier }
                if (health == nil) {
                    configuration.healthcheckSymbol2 = nil
                } else {
                    let healthStatus = HealthcheckSymbol(identifier: health!.healthtoken, display: health!.name)
                    healthStatus.events = []
                    health!.events.forEach { e in
                        let event = EventSymbol(identifier: UUID().uuidString, display: e.status!.formatted())
                        healthStatus.events?.append(event)
                    }
                    configuration.healthcheckSymbol2 = healthStatus
                }
            }
            let entry = SimpleEntry(date: .now, configuration: configuration, healthcheck: [])
            let timeline = Timeline(entries: [entry], policy: .after(.now.advanced(by: 15 * 60)))
            completion(timeline)
        }
    }
}

struct ProviderFour: IntentTimelineProvider {
    
    @AppStorage("HealthcheckList") var healthCheckList: String = ""
    
    func placeholder(in context: Context) -> SimpleFourEntry {
        var count = 2
        
        if #available(iOSApplicationExtension 16.0, *) {
            if context.family == .accessoryRectangular {
                count = 1
            } else if context.family == .systemSmall {
                count = 2
            } else if context.family == .systemMedium {
                count = 4
            } else {
                count = 9
            }
        } else {
            if context.family == .systemSmall {
                count = 2
            } else if context.family == .systemMedium {
                count = 4
            } else {
                count = 9
            }
        }
        let hc = DummyData.HealthcheckListCustom(customCount: count)
        return SimpleFourEntry(date: Date(), configuration: ConfigurationFourIntent(), healthcheck: hc)
    }
    
    func getSnapshot(for configuration: ConfigurationFourIntent, in context: Context, completion: @escaping (SimpleFourEntry) -> ()) {
        var count = 2
        if #available(iOSApplicationExtension 16.0, *) {
            if context.family == .accessoryRectangular {
                count = 1
            } else if context.family == .systemSmall {
                count = 2
            } else if context.family == .systemMedium {
                count = 4
            } else {
                count = 9
            }
        } else {
            if context.family == .systemSmall {
                count = 2
            } else if context.family == .systemMedium {
                count = 4
            } else {
                count = 9
            }
        }
        let hc = DummyData.HealthcheckListCustom(customCount: count)
        let entry = SimpleFourEntry(date: Date(), configuration: configuration, healthcheck: hc)
        completion(entry)
    }
    
    func getTimeline(for configuration: ConfigurationFourIntent, in context: Context, completion: @escaping (Timeline<SimpleFourEntry>) -> ()) {
        Task {
            let api = NetworkServices()
            let hcd = DummyData.HealthcheckListCustom(customCount: 4)
            let hcr = await api.GetHealthchecks() ?? HealthCheckResult(domain: hcd)
            
            let sorted = hcr.domain.sorted { $0.name > $1.name }
            let shrinkedEventList = Array(sorted)
            if (configuration.healthcheckSymbol11 != nil) {
                let health = shrinkedEventList.first { $0.healthtoken == configuration.healthcheckSymbol11?.identifier }
                if (health == nil) {
                    configuration.healthcheckSymbol11 = nil
                } else {
                    let healthStatus = HealthcheckSymbol(identifier: health!.healthtoken, display: health!.name)
                    healthStatus.events = []
                    health!.events.forEach { e in
                        let event = EventSymbol(identifier: UUID().uuidString, display: e.status!.formatted())
                        healthStatus.events?.append(event)
                    }
                    configuration.healthcheckSymbol11 = healthStatus
                }
            }
            if (configuration.healthcheckSymbol12 != nil) {
                let health = shrinkedEventList.first { $0.healthtoken == configuration.healthcheckSymbol12?.identifier }
                if (health == nil) {
                    configuration.healthcheckSymbol12 = nil
                } else {
                    let healthStatus = HealthcheckSymbol(identifier: health!.healthtoken, display: health!.name)
                    healthStatus.events = []
                    health!.events.forEach { e in
                        let event = EventSymbol(identifier: UUID().uuidString, display: e.status!.formatted())
                        healthStatus.events?.append(event)
                    }
                    configuration.healthcheckSymbol12 = healthStatus
                }
            }
            /*if (configuration.healthcheckSymbol21 != nil) {
                let health = shrinkedEventList.first { $0.healthtoken == configuration.healthcheckSymbol21?.identifier }
                if (health == nil) {
                    configuration.healthcheckSymbol21 = nil
                } else {
                    let healthStatus = HealthcheckSymbol(identifier: health!.healthtoken, display: health!.name)
                    healthStatus.events = []
                    health!.events.forEach { e in
                        let event = EventSymbol(identifier: UUID().uuidString, display: e.status!.formatted())
                        healthStatus.events?.append(event)
                    }
                    configuration.healthcheckSymbol21 = healthStatus
                }
            }
            if (configuration.healthcheckSymbol22 != nil) {
                let health = shrinkedEventList.first { $0.healthtoken == configuration.healthcheckSymbol22?.identifier }
                if (health == nil) {
                    configuration.healthcheckSymbol22 = nil
                } else {
                    let healthStatus = HealthcheckSymbol(identifier: health!.healthtoken, display: health!.name)
                    healthStatus.events = []
                    health!.events.forEach { e in
                        let event = EventSymbol(identifier: UUID().uuidString, display: e.status!.formatted())
                        healthStatus.events?.append(event)
                    }
                    configuration.healthcheckSymbol22 = healthStatus
                }
            }*/
            let entry = SimpleFourEntry(date: .now, configuration: configuration, healthcheck: [])
            let timeline = Timeline(entries: [entry], policy: .after(.now.advanced(by: 15 * 60)))
            completion(timeline)
        }
    }
}

struct ProviderStatic: TimelineProvider {
    
    @AppStorage("HealthcheckList") var healthCheckList: String = ""
    
    func placeholder(in context: Context) -> SimpleEntryStatic {
        var count = 2
        if #available(iOSApplicationExtension 16.0, *) {
            if context.family == .accessoryRectangular {
                count = 1
            } else if context.family == .systemSmall {
                count = 2
            } else if context.family == .systemMedium {
                count = 4
            } else {
                count = 9
            }
        } else {
            if context.family == .systemSmall {
                count = 2
            } else if context.family == .systemMedium {
                count = 4
            } else {
                count = 9
            }
        }
        let hc = DummyData.HealthcheckListCustom(customCount: count)
        return SimpleEntryStatic(date: Date(), healthcheck: hc)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntryStatic) -> Void) {
        var count = 2
        if #available(iOSApplicationExtension 16.0, *) {
            if context.family == .accessoryRectangular {
                count = 1
            } else if context.family == .systemSmall {
                count = 2
            } else if context.family == .systemMedium {
                count = 4
            } else {
                count = 9
            }
        } else {
            if context.family == .systemSmall {
                count = 2
            } else if context.family == .systemMedium {
                count = 4
            } else {
                count = 9
            }
        }
        let hc = DummyData.HealthcheckListCustom(customCount: count)
        let entry = SimpleEntryStatic(date: Date(), healthcheck: hc)
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntryStatic>) -> Void) {
        Task {
            let api = NetworkServices()
            let hcd = DummyData.HealthcheckListCustom(customCount: 2)
            let hcr = await api.GetHealthchecks() ?? HealthCheckResult(domain: hcd)
            var count = 2
            if #available(iOSApplicationExtension 16.0, *) {
                if context.family == .accessoryRectangular {
                    count = 1
                } else if context.family == .systemSmall {
                    count = 2
                } else if context.family == .systemMedium {
                    count = 4
                } else {
                    count = 10
                }
            } else {
                if context.family == .systemSmall {
                    count = 2
                } else if context.family == .systemMedium {
                    count = 4
                } else {
                    count = 10
                }
            }
            let sorted = hcr.domain.prefix(count).sorted { $0.name > $1.name }
            let shrinkedEventList = Array(sorted)
            let entry = SimpleEntryStatic(date: .now, healthcheck: shrinkedEventList)
            let timeline = Timeline(entries: [entry], policy: .after(.now.advanced(by: 15 * 60)))
            completion(timeline)
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationIntent
    let healthcheck: [HealthCheck]
}

struct SimpleFourEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationFourIntent
    let healthcheck: [HealthCheck]
}

struct SimpleEntryStatic: TimelineEntry {
    let date: Date
    let healthcheck: [HealthCheck]
}

struct HealthcheckWidgetEntryView : View {
    @Environment(\.widgetFamily) var widgetFamily
    
    var entry: Provider.Entry
    
    var body: some View {
        if #available(iOSApplicationExtension 16.0, *) {
            switch widgetFamily {
            case .systemSmall:
                SmallSizeView(entry: entry)
                    .widgetURL(URL(string: "ipv64://tab/2"))
            case .accessoryRectangular:
                AccessoryRectangleView(entry: entry)
                    .widgetURL(URL(string: "ipv64://tab/2"))
            default:
                Text("Not implemented!")
            }
        } else {
            // Fallback on earlier versions
            switch widgetFamily {
            case .systemSmall:
                SmallSizeView(entry: entry)
                    .widgetURL(URL(string: "ipv64://tab/2"))
            default:
                Text("Not implemented!")
            }
        }
    }
}

//struct HealthcheckWidgetFourEntryView : View {
//    @Environment(\.widgetFamily) var widgetFamily
//    
//    var entry: ProviderFour.Entry
//    
//    var body: some View {
//        if #available(iOSApplicationExtension 16.0, *) {
//            switch widgetFamily {
//            case .systemMedium:
//                MediumSizeView(entry: entry)
//                    .widgetURL(URL(string: "ipv64://tab/2"))
//            default:
//                Text("Not implemented!")
//            }
//        } else {
//            // Fallback on earlier versions
//            switch widgetFamily {
//            case .systemMedium:
//                MediumSizeView(entry: entry)
//                    .widgetURL(URL(string: "ipv64://tab/2"))
//            default:
//                Text("Not implemented!")
//            }
//        }
//    }
//}

struct HealthcheckWidgetStaticEntryView : View {
    @Environment(\.widgetFamily) var widgetFamily
    
    var entry: ProviderStatic.Entry
    
    var body: some View {
        switch widgetFamily {
        case .systemMedium:
            MediumSizeView(entry: entry)
                .widgetURL(URL(string: "ipv64://tab/2"))
        case .systemLarge:
            LargeSizeView(entry: entry)
                .widgetURL(URL(string: "ipv64://tab/2"))
        default:
            Text("Not implemented!")
        }
    }
}

struct HealthcheckWidget: Widget {
    let kind: String = "HealthcheckWidget"
    
    private var supportedFamilies: [WidgetFamily] {
        if #available(iOSApplicationExtension 16.0, *) {
            return [
                .systemSmall,
                .accessoryRectangular
            ]
        } else {
            return [
                .systemSmall
            ]
        }
    }
    
    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: Provider()) { entry in
            HealthcheckWidgetEntryView(entry: entry)
        }
        .supportedFamilies(supportedFamilies)
        .configurationDisplayName("Meine Healthchecks")
        .description("Hier werden dir deine Healthchecks angezeigt.")
        .contentMarginsDisabled()
    }
}

struct HealthcheckWidgetStatic: Widget {
    let kind: String = "HealthcheckWidgetStatic"
    
    private var supportedFamilies: [WidgetFamily] {
        return [
            .systemMedium,
            .systemLarge
        ]
    }
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ProviderStatic()) { entry in
            HealthcheckWidgetStaticEntryView(entry: entry)
        }
        .supportedFamilies(supportedFamilies)
        .configurationDisplayName("Meine Healthchecks")
        .description("Hier werden dir deine Healthchecks angezeigt.")
        .contentMarginsDisabled()
    }
}

//struct HealthcheckWidgetFour: Widget {
//    let kind: String = "HealthcheckWidgetFour"
//    
//    private var supportedFamilies: [WidgetFamily] {
//        if #available(iOSApplicationExtension 16.0, *) {
//            return [
//                .systemMedium
//            ]
//        } else {
//            return [
//                .systemMedium
//            ]
//        }
//    }
//    
//    var body: some WidgetConfiguration {
//        IntentConfiguration(kind: kind, intent: ConfigurationFourIntent.self, provider: ProviderFour()) { entry in
//            HealthcheckWidgetFourEntryView(entry: entry)
//        }
//        .supportedFamilies(supportedFamilies)
//        .configurationDisplayName("Meine Healthchecks")
//        .description("Hier werden dir deine Healthchecks angezeigt.")
//        .contentMarginsDisabled()
//    }
//}

extension View {
    func widgetBackground(backgroundView: some View) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            return containerBackground(for: .widget) {
                backgroundView
            }
        } else {
            return background(backgroundView)
        }
    }
}

struct HealthcheckWidget_Previews: PreviewProvider {
    static var previews: some View {
        let hc = DummyData.HealthcheckListCustom(customCount: 4)
        HealthcheckWidgetEntryView(entry: SimpleEntry(date: Date(), configuration: ConfigurationIntent(), healthcheck: hc))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
