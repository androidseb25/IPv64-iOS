//
//  DummyData.swift
//  IPv64
//
//  Created by Sebastian Rank on 04.11.25.
//
import Foundation

struct DummyData {
    static var Healthcheck = HealthCheck(
        name: "Healthcheck Test",
        healthstatus: 3,
        healthtoken: "123456789abcdefghijklmnop",
        add_time: "2023-01-01 00:00:00",
        last_update_time: "2023-01-01 00:00:00",
        alarm_time: "2023-01-01 00:00:00",
        alarm_down: 0,
        alarm_up: 0,
        integration_id: "0",
        alarm_count: 1,
        alarm_unit: 1,
        grace_count: 1,
        grace_unit: 1,
        pings_total: 1,
        events: [
            HealthEvents(
                event_time: "2023-01-01 00:45:00",
                status: 1,
                text: "123456789"
            ),
            HealthEvents(
                event_time: "2023-01-01 01:00:00",
                status: 4,
                text: "WARNING: Zeitlimit erreicht, Karenzzeit hat begonnen."
            ),
            HealthEvents(
                event_time: "2023-01-01 00:45:00",
                status: 3,
                text: "123456789"
            ),
            HealthEvents(
                event_time: "2023-01-01 00:45:00",
                status: 0,
                text: "GET Request von 194.126.177.83 -- Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.3 Safari/605.1.15"
            ),
            HealthEvents(
                event_time: "2023-01-01 00:00:00",
                status: 1,
                text: Optional("Healthcheck Einstellungen übernommen.")
            ),
            HealthEvents(
                event_time: "2023-01-01 00:45:00",
                status: 4,
                text: "123456789"
            ),
            HealthEvents(
                event_time: "2023-01-01 01:00:00",
                status: 3,
                text: "WARNING: Zeitlimit erreicht, Karenzzeit hat begonnen."
            ),
            HealthEvents(
                event_time: "2023-01-01 00:45:00",
                status: 0,
                text: "123456789"
            ),
            HealthEvents(
                event_time: "2023-01-01 00:45:00",
                status: 1,
                text: "GET Request von 194.126.177.83 -- Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.3 Safari/605.1.15"
            ),
            HealthEvents(
                event_time: "2023-01-01 00:00:00",
                status: 4,
                text: Optional("Healthcheck Einstellungen übernommen.")
            ),
            HealthEvents(
                event_time: "2023-01-01 00:45:00",
                status: 3,
                text: "123456789"
            )
        ]
    )
    
    static func HealthcheckListCustom(customCount: Int) -> [HealthCheck] {
        var list: [HealthCheck] = []
        for i in 0..<customCount {
            var hc = self.Healthcheck
            hc.name = "Healthcheck \(i+1)"
            hc.healthtoken = "123456789abcdefghijklmnop\(i+1)"
            list.append(hc)
        }
        return list
    }
    
}
