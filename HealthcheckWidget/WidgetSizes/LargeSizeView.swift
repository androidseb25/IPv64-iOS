//
//  LargeSizeView.swift
//  IPv64
//
//  Created by Sebastian Rank on 20.01.23.
//

import Foundation
import WidgetKit
import SwiftUI

struct LargeSizeView : View {
    @Environment(\.widgetFamily) var widgetFamily
    
    var entry: ProviderStatic.Entry
    
    var body: some View {
        ZStack {
            Color("circleBG")
            HStack {
                let firstColumn = GetColumn(start: 0, end: 4)
                let secondColumn = GetColumn(start: 5, end: 9)
                VStack {
                    ForEach(firstColumn, id: \.healthtoken) { it in
                        LazyVStack(alignment: .leading, spacing: 0) {
                            Text(it.name)
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
                    if (firstColumn.count < 5) {
                        Spacer()
                    }
                }
                .padding(.top, firstColumn.count < 5 ? 4 : 0)
                VStack {
                    ForEach(secondColumn, id: \.healthtoken) { it in
                        LazyVStack(alignment: .leading, spacing: 0) {
                            Text(it.name)
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
                    if (secondColumn.count < 5) {
                        Spacer()
                    }
                }
                .padding(.top, secondColumn.count < 5 ? 4 : 0)
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
    
    fileprivate func GetColumn(start: Int, end: Int) -> ArraySlice<HealthCheck> {
        if (entry.healthcheck.count < start) {
            return []
        } else if (entry.healthcheck.count > end) {
            return entry.healthcheck[start...end]
        } else if (entry.healthcheck.count == 1) {
            return entry.healthcheck[start...start]
        } else if (entry.healthcheck.count == 0) {
            return []
        }  else if (entry.healthcheck.count < end) {
            return entry.healthcheck[start...entry.healthcheck.count-1]
        } else {
            return entry.healthcheck[start...end-1]
        }
    }
}


struct LargeSizeViewPreviews: PreviewProvider {
    static var previews: some View {
        let hc = DummyData.HealthcheckListCustom(customCount: 9)
        LargeSizeView(entry: SimpleEntryStatic(date: Date(), healthcheck: hc))
            .previewContext(WidgetPreviewContext(family: .systemLarge))
            .preferredColorScheme(.light)
            .previewDisplayName("Light Mode")
        LargeSizeView(entry: SimpleEntryStatic(date: Date(), healthcheck: hc))
            .previewContext(WidgetPreviewContext(family: .systemLarge))
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
    }
}

