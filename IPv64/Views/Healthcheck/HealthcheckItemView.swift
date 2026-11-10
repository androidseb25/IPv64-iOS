//
//  HealthcheckItemView.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 27.10.25.
//

import SwiftUI

struct HealthcheckItemView: View {
    
    let healthcheck: HealthCheck
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(healthcheck.name)
                .multilineTextAlignment(.leading)
                .lineLimit(1)
                .font(.title3)
                .fontWeight(.bold)
                .padding(.bottom, 2)
            HealthcheckEventView(showSmall: true, events: healthcheck.events)
        }
    }
}

#Preview {
    let hc = HealthCheck(name: "001 - Dumm", healthstatus: 4, healthtoken: "4sd65fg1465ds41f6146sf5g465s4f6", add_time: "2025-10-07 08:01:22", last_update_time: "2025-10-07 08:02:06", alarm_time: "2025-10-12 13:01:03", alarm_down: 1, alarm_up: 1, integration_id: "1107,1108,1110", alarm_count: 1, alarm_unit: 1, grace_count: 30, grace_unit: 1, pings_total: 2, type: "health", events: [HealthEvents(event_time: "2025-10-12 13:00:03", status: 0, text: "Healthcheck settings saved"), HealthEvents(event_time: "2025-10-10 17:27:16", status: 0, text: "Healthcheck settings saved"), HealthEvents(event_time: "2025-10-10 17:22:38", status: 0, text: "Healthcheck settings saved"), HealthEvents(event_time: "2025-10-10 17:22:24", status: 0, text: "Healthcheck settings saved"), HealthEvents(event_time: "2025-10-10 17:19:30", status: 0, text: "Healthcheck settings saved"), HealthEvents(event_time: "2025-10-07 08:04:10", status: 4, text: "ALARM: Ein Alarm wurde ausgelöst. (001 - Dumm"), HealthEvents(event_time: "2025-10-07 08:03:06", status: 3, text: "WARNING: Zeitlimit erreicht, Karenzzeit hat begonnen."), HealthEvents(event_time: "2025-10-07 08:02:06", status: 1, text: "GET Request von 88.73.209.239 -- Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Mobile Safari/537.36"), HealthEvents(event_time: "2025-10-07 08:01:50", status: 0, text: "Healthcheck settings saved"), HealthEvents(event_time: "2025-10-07 08:01:26", status: 1, text: "GET Request von 88.73.209.239 -- Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Mobile Safari/537.36")])
    List {
        HealthcheckItemView(healthcheck: hc)
    }
}
