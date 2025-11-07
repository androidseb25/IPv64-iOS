//
//  HealthcheckWidgetView.swift
//  IPv64WidgetExtension
//
//  Created by Sebastian Rank on 07.11.25.
//

import Foundation
import SwiftUI
import WidgetKit
import SwiftyBeaver

struct HealthcheckWidgetView: View {
    
    @Environment(\.widgetFamily) var widgetFamily
    
    let items: [HealthCheckEntity]
    
    var body: some View {
        if (items.count > 0) {
            if widgetFamily == .systemSmall {
                smallWidget
            } else {
                mediumLargeWidget
            }
        } else {
            Text("No Configuration found")
        }
    }
    
    private var mediumLargeWidget: some View {
        HStack(alignment: .top) {
            let startFirst = 0
            let endFirst = widgetFamily == .systemLarge ? 4 : 1
            let startSecond = widgetFamily == .systemLarge ? 5 : 2
            let endSecond = widgetFamily == .systemLarge ? 9 : 3
            let firstColumn = GetColumn(start: startFirst, end: endFirst)
            let secondColumn = GetColumn(start: startSecond, end: endSecond)
            
            VStack {
                ForEach(firstColumn, id:\.id) { hc in
                    container(hc)
                    
                    if (firstColumn.count < startSecond) {
                        Spacer()
                    }
                }
            }
            .padding(.top, GetPadding(firstColumn.count, isFirst: true))
            
            VStack {
                ForEach(secondColumn, id:\.id) { hc in
                    container(hc)
                }
                
                if (secondColumn.count < startSecond) {
                    Spacer()
                }
            }
            .padding(.top, GetPadding(secondColumn.count, isFirst: false))
        }
        .containerBackground(for: .widget) {
            // 👇 Hintergrund für System-Widget-Rendering
            Color(.systemBackground)
        }
    }
    
    private var smallWidget: some View {
        VStack(alignment: .leading) {
            let firstColumn = GetColumn(start: 0, end: 1)
            ForEach(firstColumn, id: \.id) { hc in
                container(hc)
                
                if (firstColumn.count < 2) {
                    Spacer()
                }
            }
        }
        .containerBackground(for: .widget) {
            // 👇 Hintergrund für System-Widget-Rendering
            Color(.systemBackground)
        }
    }
    
    private func GetPadding(_ columnCount: Int, isFirst: Bool) -> CGFloat {
        if (widgetFamily == .systemLarge) {
            if (isFirst && columnCount < 5) {
                return 4
            }
            return 0
        } else {
            if (isFirst && columnCount == 1) {
                return 3
            }
            return 0
        }
    }
    
    private func container(_ hc: HealthCheckEntity) -> some View {
        LazyVStack(alignment: .leading, spacing: 5) {
            Text(hc.name)
                .font(.system(.title3, design: .rounded))
                .lineLimit(1)
            HealthcheckEventView(showSmall: true, events: hc.events)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .id(UUID())
    }
    
    fileprivate func GetColumn(start: Int, end: Int) -> ArraySlice<HealthCheckEntity> {
        if (items.count < start) {
            iLogger.log.info("items.count < start")
            return []
        }
        if (items.count > end) {
            iLogger.log.info("items.count > end")
            return items[start...end]
        }
        if (items.count == 1) {
            iLogger.log.info("items.count == 1")
            return items[start...start]
        }
        if (items.count == 0) {
            iLogger.log.info("items.count == 0")
            return []
        }
        if (items.count < end) {
            iLogger.log.info("items.count < end")
            if (items.count == start) {
                iLogger.log.info("items.count == start")
                return []
            }
            iLogger.log.info("items[start...items.count-1]")
            return items[start...items.count-1]
        } else {
            iLogger.log.info("items[start...end-1]")
            return items[start...end-1]
        }
    }
}
