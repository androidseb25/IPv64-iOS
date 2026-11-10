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
    var updatedAt: Date? = nil
    var isStale = false
    
    var body: some View {
        VStack(spacing: 4) {
            if items.isEmpty {
                Text("Choose healthchecks in Edit Widget")
            } else {
                if widgetFamily == .systemSmall { smallWidget }
                else { mediumLargeWidget }
                HStack(spacing: 3) {
                    if isStale { Image(systemName: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90") }
                    if let updatedAt {
                        Text("Updated")
                        Text(updatedAt, style: .time)
                    } else { Text("Waiting for update") }
                }
                .font(.caption2)
                .foregroundStyle(isStale ? .orange : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
        }
        .containerBackground(for: .widget) { Color(.systemBackground) }
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
