//
//  SmallSizeView.swift
//  IPv64
//
//  Created by Sebastian Rank on 20.01.23.
//

import Foundation
import WidgetKit
import SwiftUI

struct SmallSizeView : View {
    @Environment(\.widgetFamily) var widgetFamily
    
    var entry: Provider.Entry
    
    var body: some View {
        ZStack {
            Color("circleBG")
            VStack {
                ForEach(entry.healthcheck.prefix(2), id: \.healthtoken) { it in
                    LazyVStack(alignment: .leading, spacing: 0) {
                        Text(it.name!)
                            .font(.system(.title3, design: .rounded))
                            .lineLimit(1)
                        Spacer()
                        HStack(spacing: 4) {
                            let lastXPills = GetLastXMonitorPills(count: 12, domain: it).reversed()
                            ForEach(lastXPills, id:\.self) { color in
                                RoundedRectangle(cornerRadius: 5).fill(color)
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
            .padding()
        }
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
            return StatusTypes.active.color!
        }
        if (statusId == StatusTypes.warning.statusId) {
            return StatusTypes.warning.color!
        }
        if (statusId == StatusTypes.alarm.statusId) {
            return StatusTypes.alarm.color!
        }
        if (statusId == StatusTypes.pause.statusId) {
            return StatusTypes.pause.color!
        }
        
        return .gray
    }
}

struct SmallSizeViewPreviews: PreviewProvider {
    static var previews: some View {
        let hc = DummyData.HealthcheckListCustom(customCount: 2)
        SmallSizeView(entry: SimpleEntry(date: Date(), configuration: ConfigurationIntent(), healthcheck: hc))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .preferredColorScheme(.light)
            .previewDisplayName("Light Mode")
        SmallSizeView(entry: SimpleEntry(date: Date(), configuration: ConfigurationIntent(), healthcheck: hc))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
    }
}

