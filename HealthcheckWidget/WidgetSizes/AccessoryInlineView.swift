//
//  SmallSizeView.swift
//  IPv64
//
//  Created by Sebastian Rank on 20.01.23.
//

import Foundation
import WidgetKit
import SwiftUI

struct AccessoryRectangleView : View {
    @Environment(\.widgetFamily) var widgetFamily
    
    var entry: Provider.Entry
    
    var body: some View {
        ZStack {
            VStack {
                ForEach(entry.healthcheck.prefix(1), id: \.healthtoken) { it in
                    LazyVStack(alignment: .leading, spacing: 0) {
                        Text(it.name)
                            .font(.system(.callout, design: .rounded))
                            .lineLimit(1)
                        Spacer()
                        HStack(spacing: 4) {
                            let lastXPills = GetLastXMonitorPills(count: 12, domain: it).reversed()
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
                }
            }
            .padding(0)
        }
        .privacySensitive()
    }
    
    fileprivate func GetLastXMonitorPills(count: Int, domain: HealthCheck) -> [Color] {
        
        let lastEvents = domain.events.prefix(count)
        var colorArr: [Color] = []
        
        lastEvents.forEach { event in
            colorArr.append(SetDotColor(statusId: event.status!))
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

