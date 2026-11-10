//
//  HealthcheckEventView.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 27.10.25.
//

import SwiftUI

struct HealthcheckEventView: View {
    var showSmall: Bool = true
    let events: [HealthEvents]
    
    var body: some View {
        GeometryReader { geometry in
            
            // Einzelbalken-Größe
            let barWidth: CGFloat = showSmall ? 5 : 7
            let barSpacing: CGFloat = 5
            
            let availableWidth = geometry.size.width
            // Wieviele Balken passen nebeneinander?
            let totalBarWidth = barWidth + barSpacing
            let maxCount = Int(availableWidth / totalBarWidth)
            
            // Nur so viele Events anzeigen, wie reinpassen (neueste zuerst)
            let visibleEvents = Array(events.prefix(maxCount))
            let reversedEvents = visibleEvents.reversed()
            
            HStack(spacing: barSpacing) {
                ForEach(reversedEvents, id: \.event_time) { event in
                    RoundedRectangle(cornerRadius: 5)
                        .fill(event.HealthStatus.color)
                        .frame(width: barWidth, height: showSmall ? 20 : 34)
                }
            }
            .frame(width: availableWidth, alignment: .leading)
        }
        .frame(height: showSmall ? 20 : 34)
    }
}

#Preview {
    let events = [HealthEvents(event_time: "2025-10-12 13:00:03", status: 0, text: "Healthcheck settings saved"), HealthEvents(event_time: "2025-10-10 17:27:16", status: 0, text: "Healthcheck settings saved"), HealthEvents(event_time: "2025-10-10 17:22:38", status: 0, text: "Healthcheck settings saved"), HealthEvents(event_time: "2025-10-10 17:22:24", status: 0, text: "Healthcheck settings saved"), HealthEvents(event_time: "2025-10-10 17:19:30", status: 0, text: "Healthcheck settings saved"), HealthEvents(event_time: "2025-10-07 08:04:10", status: 4, text: "ALARM: Ein Alarm wurde ausgelöst. (001 - Dumm"), HealthEvents(event_time: "2025-10-07 08:03:06", status: 3, text: "WARNING: Zeitlimit erreicht, Karenzzeit hat begonnen."), HealthEvents(event_time: "2025-10-07 08:02:06", status: 1, text: "GET Request von 88.73.209.239 -- Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Mobile Safari/537.36"), HealthEvents(event_time: "2025-10-07 08:01:50", status: 0, text: "Healthcheck settings saved"), HealthEvents(event_time: "2025-10-07 08:01:26", status: 1, text: "GET Request von 88.73.209.239 -- Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Mobile Safari/537.36"),HealthEvents(event_time: "2025-10-12 13:00:03", status: 0, text: "Healthcheck settings saved"), HealthEvents(event_time: "2025-10-10 17:27:16", status: 0, text: "Healthcheck settings saved"), HealthEvents(event_time: "2025-10-10 17:22:38", status: 0, text: "Healthcheck settings saved"), HealthEvents(event_time: "2025-10-10 17:22:24", status: 0, text: "Healthcheck settings saved"), HealthEvents(event_time: "2025-10-10 17:19:30", status: 0, text: "Healthcheck settings saved"), HealthEvents(event_time: "2025-10-07 08:04:10", status: 4, text: "ALARM: Ein Alarm wurde ausgelöst. (001 - Dumm")]
    HealthcheckEventView(events: events)
}
