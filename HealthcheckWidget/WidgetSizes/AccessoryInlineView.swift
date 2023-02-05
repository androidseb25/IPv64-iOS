//
//  SmallSizeView.swift
//  IPv64
//
//  Created by Sebastian Rank on 20.01.23.
//

import Foundation
import WidgetKit
import SwiftUI


@available(iOSApplicationExtension 16.0, *)
struct AccessoryRectangleView : View {
    @Environment(\.widgetFamily) var widgetFamily
    
    var entry: Provider.Entry
    
    var body: some View {
        ZStack {
            VStack {
                if (entry.configuration.healthcheckSymbol1 != nil) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        Text(entry.configuration.healthcheckSymbol1!.displayString)
                            .font(.system(.callout, design: .rounded))
                            .lineLimit(1)
                        Spacer()
                        HStack(spacing: 4) {
                            let lastXPills = GetLastXMonitorPills(count: 12, events: entry.configuration.healthcheckSymbol1!.events!)
                            ForEach(lastXPills, id:\.self) { color in
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(color)
                                    .frame(width: 7, height: 25)
                            }
                        }
                        .padding(.trailing, 5)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(UUID())
                    .padding(.bottom, 5)
                } else {
                    Text("Keine Healthchecks konfiguriert!")
                        .font(.system(.callout, design: .rounded))
                }
            }
            .padding(0)
        }
        .privacySensitive()
    }
    
    fileprivate func GetLastXMonitorPills(count: Int, events: [EventSymbol]) -> [Color] {
        var colorArr: [Color] = []
        let lastEvents = events.prefix(count)
        print("lastEvents")
        lastEvents.reversed().forEach { event in
            colorArr.append(SetDotColor(statusId: Int(event.displayString) ?? 0))
        }
        return colorArr
    }
    
    fileprivate func SetDotColor(statusId: Int) -> Color {
        if (statusId == StatusTypes.active.statusId) {
            return .white
        }
        if (statusId == StatusTypes.warning.statusId) {
            return .white.opacity(0.6)
        }
        if (statusId == StatusTypes.alarm.statusId) {
            return .white.opacity(0.3)
        }
        
        return .white.opacity(0.1)
    }
}

@available(iOSApplicationExtension 16.0, *)
struct AccessoryRectanglePreviews: PreviewProvider {
    static var previews: some View {
        let hc = DummyData.HealthcheckListCustom(customCount: 1)
        AccessoryRectangleView(entry: SimpleEntry(date: Date(), configuration: ConfigurationIntent(), healthcheck: hc))
            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
            .preferredColorScheme(.light)
            .previewDisplayName("Light Mode")
        AccessoryRectangleView(entry: SimpleEntry(date: Date(), configuration: ConfigurationIntent(), healthcheck: hc))
            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
    }
}

