//
//  DetailHealthcheckView.swift
//  IPv64
//
//  Created by Sebastian Rank on 17.01.23.
//

import SwiftUI

struct DetailHealthcheckView: View {
    
    @Environment(\.presentationMode) var presentationMode
    
    @State var healthcheck: HealthCheck?
    
    @ObservedObject var api: NetworkServices = NetworkServices()
    @State var activeSheet: ActiveSheet? = nil
    @State var errorTyp: ErrorTyp? = .none
    
    @State var pillCount = 15
    
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
    
    fileprivate func GetLastXMonitorPills(count: Int, domain: HealthCheck) -> [Color] {
        
        print("COUNT: \(domain.events.suffix(count).count) PillCount: \(count)")
        let lastEvents = domain.events.suffix(count)
        var colorArr: [Color] = []
        lastEvents.forEach { event in
            colorArr.append(SetDotColor(statusId: event.status!))
        }
        
        return colorArr
    }
    
    fileprivate func GetLastXMonitor(count: Int, domain: HealthCheck) -> [HealthEvents] {
        
        print("COUNT: \(domain.events.suffix(count).count) HealthCount: \(count)")
        let lastEvents = domain.events.suffix(count)
        var healthArr: [HealthEvents] = []
        lastEvents.forEach { event in
            healthArr.append(event)
        }
        
        return healthArr
    }
    
    fileprivate func GetUnit(unitId: Int) -> String {
        if (unitId == AlarmUnitTypes.minutes.id) {
            return AlarmUnitTypes.minutes.text!
        } else if (unitId == AlarmUnitTypes.stunden.id) {
            return AlarmUnitTypes.stunden.text!
        } else {
            return AlarmUnitTypes.tage.text!
        }
    }
    
    fileprivate func GetHealthUpdateUrl() -> String {
        return "https://ipv64.net/health.php?token=" + (healthcheck?.healthtoken!)!
    }
    
    var body: some View {
        ZStack {
            GeometryReader { geo in
                let countPills = geo.size.width / 17
                VStack { }
                    .onAppear { pillCount = Int(countPills) }
            }
            Form {
                HStack {
                    Spacer()
                    HStack(spacing: 6) {
                        let lastXPills = GetLastXMonitorPills(count: Int(pillCount), domain: healthcheck!).reversed()
                        ForEach(lastXPills, id:\.self) { color in
                            RoundedRectangle(cornerRadius: 5).fill(color)
                                .frame(width: 9, height: 40)
                        }
                    }
                    Spacer()
                }
                .frame(height: 60)
                .listStyle(.plain)
                .listRowInsets(EdgeInsets(top: 15, leading: 0, bottom: 0, trailing: 0))
                .listRowBackground(Color.clear)
                .id(UUID())
                Section("Healthcheck Einstellungen") {
                    HStack {
                        Text("Zeitraum")
                        Spacer()
                        Text("\(healthcheck!.alarm_count!) \(GetUnit(unitId: healthcheck!.alarm_unit!))")
                            .foregroundColor(.gray)
                    }
                    HStack {
                        Text("Karenzzeit")
                        Spacer()
                        Text("\(healthcheck!.grace_count!) \(GetUnit(unitId: healthcheck!.grace_unit!))")
                            .foregroundColor(.gray)
                    }
                    HStack {
                        Text("Benachrichtung bei DOWN")
                        Spacer()
                        Text(healthcheck!.alarm_down! != 0 ? "aktiv" : "deaktiviert")
                            .foregroundColor(.gray)
                    }
                    .foregroundColor(.red)
                    HStack {
                        Text("Benachrichtung bei UP")
                        Spacer()
                        Text(healthcheck!.alarm_up! != 0 ? "aktiv" : "deaktiviert")
                            .foregroundColor(.gray)
                    }
                    .foregroundColor(.green)
                    let dateDateCreated = dateDBFormatter.date(from: (healthcheck?.add_time)!)
                    let dateCreatedString = itemFormatter.string(from: dateDateCreated ?? Date())
                    HStack {
                        Text("erstellt am")
                        Spacer()
                        Text(dateCreatedString)
                            .foregroundColor(.gray)
                    }
                    HStack {
                        Text("Health Update URL:")
                        Spacer()
                        Text(GetHealthUpdateUrl())
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .none, action: {
                            UIPasteboard.general.string = GetHealthUpdateUrl()
                        }) {
                            Label("Health Update URL", systemImage: "doc.on.doc")
                        }
                        .tint(.blue)
                    }
                }
                Section("Logs") {
                    let list = GetLastXMonitor(count: Int(pillCount), domain: healthcheck!)
                    ForEach(list, id:\.event_time) { event in
                        LazyVStack {
                            let dateDate = dateDBFormatter.date(from: event.event_time!)
                            let dateString = itemFormatter.string(from: dateDate ?? Date())
                            HStack {
                                Image(systemName: "circle.fill")
                                    .resizable()
                                    .scaledToFill()
                                    .foregroundColor(SetDotColor(statusId: event.status!))
                                    .frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(dateString)
                                        .multilineTextAlignment(.leading)
                                        .font(.system(.callout, design: .rounded))
                                    Text(event.text!)
                                        .multilineTextAlignment(.leading)
                                        .font(.system(.caption2, design: .rounded))
                                }
                                .padding(.leading, 5)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
            }
            .navigationTitle((healthcheck?.name)!)
            .toolbar {
                ToolbarItem {
                    /*Button(action: {
                     //activeSheet = .adddns
                     }) {
                     Image(systemName: "square.and.pencil")
                     .symbolRenderingMode(.hierarchical)
                     .foregroundColor(Color("primaryText"))
                     }
                     .foregroundColor(.black)*/
                }
            }
            .sheet(item: $activeSheet) { item in
                showActiveSheet(item: item)
            }
            if api.isLoading {
                VStack() {
                    Spinner(isAnimating: true, style: .large, color: .white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.3).ignoresSafeArea())
            }
        }
    }
    
    @ViewBuilder
    func showActiveSheet(item: ActiveSheet?) -> some View {
        switch item {
        case .error:
            ErrorSheetView(errorTyp: $errorTyp, deleteThisDomain: .constant(false))
                .interactiveDismissDisabled(errorTyp?.status == 202 ? false : true)
            /*.onDisappear {
             if (deleteThisDNSRecord) {
             Task {
             print(deleteDNSRecord)
             let res = await api.DeleteDNSRecord(recordId: (delDNSRecord?.record_id)!)
             print(res)
             withAnimation {
             presentationMode.wrappedValue.dismiss()
             }
             }
             }
             }*/
        default:
            EmptyView()
        }
    }
    
    private let itemFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
    }()
    
    private let dateDBFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}

struct DetailHealthcheckView_Previews: PreviewProvider {
    static var previews: some View {
        let hcd = HealthCheck(
            name: Optional("Test"),
            healthstatus: Optional(2),
            healthtoken: Optional("GQRNzAVLgTpneo1jy0MYJcPhx2KUCHfa"),
            add_time: Optional("2023-01-16 21:23:55"),
            last_update_time: Optional("2023-01-17 18:04:41"),
            alarm_time: Optional("2023-01-17 18:05:41"),
            alarm_down: Optional(0),
            alarm_up: Optional(0),
            integration_id: Optional(0),
            alarm_count: Optional(1),
            alarm_unit: Optional(1),
            grace_count: Optional(1),
            grace_unit: Optional(1),
            pings_total: Optional(1),
            events: [
                HealthEvents(
                    event_time: Optional("2023-01-17 18:06:42"),
                    status: Optional(4),
                    text: Optional("ALARM: Der Alarm wurde ausgelöst.")
                ),
                HealthEvents(
                    event_time: Optional("2023-01-17 18:05:42"),
                    status: Optional(3),
                    text: Optional("WARNING: Zeitlimit erreicht, Karenzzeit hat begonnen.")
                ),
                HealthEvents(
                    event_time: Optional("2023-01-17 13:55:21"),
                    status: Optional(4),
                    text: Optional("ALARM: Der Alarm wurde ausgelöst.")
                ),
                HealthEvents(
                    event_time: Optional("2023-01-17 13:54:21"),
                    status: Optional(3),
                    text: Optional("WARNING: Zeitlimit erreicht, Karenzzeit hat begonnen.")
                ),
                HealthEvents(
                    event_time: Optional("2023-01-17 10:05:55"),
                    status: Optional(4),
                    text: Optional("ALARM: Der Alarm wurde ausgelöst.")
                ),
                HealthEvents(
                    event_time: Optional("2023-01-17 10:04:53"),
                    status: Optional(3),
                    text: Optional("WARNING: Zeitlimit erreicht, Karenzzeit hat begonnen.")
                ),
                HealthEvents(
                    event_time: Optional("2023-01-17 09:54:50"),
                    status: Optional(3),
                    text: Optional("WARNING: Zeitlimit erreicht, Karenzzeit hat begonnen.")
                ),
                HealthEvents(
                    event_time: Optional("2023-01-17 09:51:35"),
                    status: Optional(4),
                    text: Optional("ALARM: Der Alarm wurde ausgelöst.")
                ),
                HealthEvents(
                    event_time: Optional("2023-01-17 09:50:35"),
                    status: Optional(3),
                    text: Optional("WARNING: Zeitlimit erreicht, Karenzzeit hat begonnen.")
                ),
                HealthEvents(
                    event_time: Optional("2023-01-17 09:47:30"),
                    status: Optional(3),
                    text: Optional("WARNING: Zeitlimit erreicht, Karenzzeit hat begonnen.")
                ),
                HealthEvents(
                    event_time: Optional("2023-01-16 21:26:42"),
                    status: Optional(4),
                    text: Optional("ALARM: Der Alarm wurde ausgelöst.")
                ),
                HealthEvents(
                    event_time: Optional("2023-01-16 21:25:42"),
                    status: Optional(3),
                    text: Optional("WARNING: Zeitlimit erreicht, Karenzzeit hat begonnen.")
                ),
                HealthEvents(
                    event_time: Optional("2023-01-16 21:24:40"),
                    status: Optional(0),
                    text: Optional("Healthcheck Einstellungen übernommen.")
                ),
                HealthEvents(
                    event_time: Optional("2023-01-16 21:24:38"),
                    status: Optional(0),
                    text: Optional("Healthcheck Einstellungen übernommen.")
                ),
                HealthEvents(
                    event_time: Optional("2023-01-16 21:24:06"),
                    status: Optional(1),
                    text: Optional("GET Request von 88.70.111.13 -- Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.3 Safari/605.1.15")
                )
            ]
        )
        NavigationView {
            DetailHealthcheckView(healthcheck: hcd)
        }
        .preferredColorScheme(.light)
        .previewDisplayName("Light Mode")
        NavigationView {
            DetailHealthcheckView(healthcheck: hcd)
        }
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode")
    }
}
