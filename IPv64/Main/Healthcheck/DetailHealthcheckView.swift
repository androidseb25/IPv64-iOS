//
//  DetailHealthcheckView.swift
//  IPv64
//
//  Created by Sebastian Rank on 17.01.23.
//

import SwiftUI
import Charts
import Toast

struct DetailHealthcheckView: View {
    
    @Environment(\.presentationMode) var presentationMode
    @AppStorage("IntegrationList") var integrationListS: String = ""
    
    @State var healthcheck: HealthCheck?
    @Binding var isEdit: Bool
    
    @ObservedObject var api: NetworkServices = NetworkServices()
    @State var activeSheet: ActiveSheet? = nil
    @State var errorTyp: ErrorTyp? = .none
    @State var healthcheckStatus: HealthcheckStatisticsResult = HealthcheckStatisticsResult()
    
    @State var updatedItem = false
    
    @State var pillCount = 15
    
    @State var selectedPos: String? = nil
    
    fileprivate func GetIntegrationCount() -> String {
        if (healthcheck!.integration_id == "0") {
            return "0"
        }
        
        return "\(healthcheck!.integration_id.split(separator: ",").count)"
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
    
    fileprivate func GetLastXMonitorPills(count: Int, domain: HealthCheck) -> [Color] {
        let lastEvents = domain.events.prefix(count)
        var colorArr: [Color] = []
        lastEvents.forEach { event in
            colorArr.append(SetDotColor(statusId: event.status!))
        }
        
        return colorArr
    }
    
    fileprivate func GetLastXMonitor(count: Int, domain: HealthCheck) -> [HealthEvents] {
        let lastEvents = domain.events.prefix(count)
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
        return "https://ipv64.net/health.php?token=" + (healthcheck?.healthtoken)!
    }
    
    var body: some View {
        ZStack {
            GeometryReader { geo in
                let countPills = geo.size.width / 17
                VStack { }
                    .onAppear {
                        pillCount = Int(countPills)
                        if (healthcheck?.type != "health") {
                            Task {
                                healthcheckStatus = await api.GetHealthcheckStatistics(healthtoken: healthcheck!.healthtoken) ?? HealthcheckStatisticsResult()
                                print("STATSRES")
                                print(healthcheckStatus)
                            }
                        }
                    }
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
                        Text("\(healthcheck!.alarm_count) \(GetUnit(unitId: healthcheck!.alarm_unit))")
                            .foregroundColor(.gray)
                    }
                    HStack {
                        Text("Karenzzeit")
                        Spacer()
                        Text("\(healthcheck!.grace_count) \(GetUnit(unitId: healthcheck!.grace_unit))")
                            .foregroundColor(.gray)
                    }
                    HStack {
                        Text("Benachrichtungsmethode/n")
                        Spacer()
                        Text(GetIntegrationCount())
                            .foregroundColor(.gray)
                    }
                    HStack {
                        Text("Benachrichtung bei DOWN")
                        Spacer()
                        Text(healthcheck!.alarm_down != 0 ? "aktiv" : "deaktiviert")
                            .foregroundColor(.gray)
                    }
                    .foregroundColor(.red)
                    HStack {
                        Text("Benachrichtung bei UP")
                        Spacer()
                        Text(healthcheck!.alarm_up != 0 ? "aktiv" : "deaktiviert")
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
                            let toast = Toast.default(
                                image: GetUIImage(imageName: "doc.on.doc", color: UIColor.systemBlue, hierarichal: true),
                                title: "Kopiert!", config: .init(
                                    direction: .top,
                                    autoHide: true,
                                    enablePanToClose: false,
                                    displayTime: 4,
                                    enteringAnimation: .fade(alphaValue: 0.5),
                                    exitingAnimation: .slide(x: 0, y: -100))
                            )
                            toast.show(haptic: .success)
                            UIPasteboard.general.string = GetHealthUpdateUrl()
                        }) {
                            Label("Kopieren", systemImage: "doc.on.doc")
                        }
                        .tint(.blue)
                    }
                }
                if (healthcheck?.type != "health") {
                    Section("Latenzen") {
                        if #available(iOS 16.0, *) {
                            if (healthcheckStatus.statistics != nil) {
                                let gradient = Gradient(colors: [Color("ip64_color"), Color("ip64_color").opacity(0)])
                                let statKey = Array(healthcheckStatus.statistics!)[0]
                                let stats = Array(statKey.value.reversed().prefix(pillCount).reversed())
                                VStack(alignment: .leading, spacing: 4) {
                                    if (selectedPos != nil) {
                                        let item = stats.first(where: { $0.id.uuidString == selectedPos })
                                        let dateDate = dateDBTFormatter.date(from: item?.time ?? "2001-01-01")
                                        let dateString = itemFormatter.string(from: dateDate ?? Date())
                                        Text("Datum: \(dateString)")
                                            .font(.system(.headline, design: .rounded))
                                        Text("Latenz: \(item?.latency ?? 0, specifier: "%.2f") ms")
                                            .font(.system(.footnote, design: .rounded))
                                    }
                                    Chart(stats, id: \.id) {
                                        if (selectedPos != nil && $0.id.uuidString == selectedPos) {
                                            RuleMark(x: .value("Now", $0.id.uuidString))
                                                .foregroundStyle(Color.secondary)
                                                .accessibilityHidden(true)
                                            PointMark(
                                                x: .value("ID", $0.id.uuidString),
                                                y: .value("Value", $0.latency)
                                            )
                                            .symbolSize(CGSize(width: 8, height: 8))
                                            .foregroundStyle(Color.white)
                                            .accessibilityHidden(true)
                                        }
                                        LineMark(
                                            x: .value("ID", $0.id.uuidString),
                                            y: .value("Value", $0.latency)
                                        )
                                        .interpolationMethod(.catmullRom)
                                        .foregroundStyle(Color("ip64_color"))
                                        AreaMark(
                                            x: .value("ID", $0.id.uuidString),
                                            y: .value("Value", $0.latency)
                                        )
                                        .interpolationMethod(.catmullRom)
                                        .foregroundStyle(gradient)
                                    }
                                    .chartOverlay { proxy in
                                        GeometryReader { geo in
                                            Rectangle()
                                                .fill(Color.clear)
                                                .contentShape(Rectangle())
                                                .gesture(DragGesture(minimumDistance: 0)
                                                    .onChanged { value in
                                                        // find start and end positions of the drag
                                                        
                                                        let start = geo[proxy.plotAreaFrame].origin.x
                                                        let xCurrent = value.location.x - start
                                                        // map those positions to X-axis values in the chart
                                                        if let posId: String = proxy.value(atX: xCurrent) {
                                                            selectedPos = posId
                                                        }
                                                    }
                                                    .onEnded { value in
                                                        // find start and end positions of the drag
                                                        
                                                        let start = geo[proxy.plotAreaFrame].origin.x
                                                        let xCurrent = value.location.x - start
                                                        // map those positions to X-axis values in the chart
                                                        if let posId: String = proxy.value(atX: xCurrent) {
                                                            selectedPos = posId
                                                        }
                                                    })
                                        }
                                    }
                                    .chartXAxis(.hidden)
                                    .frame(height: 250)
                                    .padding(.vertical)
                                    .onAppear {
                                        selectedPos = stats[0].id.uuidString ?? ""
                                    }
                                    
                                }
                            } else {
                                VStack {
                                    Spinner(isAnimating: true, style: .medium, color: .white)
                                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                        else {
                            Text("Latenzen sind erst unter iOS 16 mit der Apple Chart Bibliothek verfügbar!")
                        }
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
                    Button(action: {
                        activeSheet = .edit
                    }) {
                        Image(systemName: "square.and.pencil")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(Color("primaryText"))
                    }
                    .foregroundColor(.black)
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
        case .edit:
            EditHealthcheckView(healthcheck: healthcheck!, updatedItem: $updatedItem)
                .onDisappear {
                    if (updatedItem) {
                        isEdit = true
                        updatedItem = false
                        withAnimation {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
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
    
    private let dateDBTFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return formatter
    }()
}

struct DetailHealthcheckView_Previews: PreviewProvider {
    static var previews: some View {
        let hcd = DummyData.Healthcheck
        NavigationView {
            DetailHealthcheckView(healthcheck: hcd, isEdit: .constant(false))
        }
        .preferredColorScheme(.light)
        .previewDisplayName("Light Mode")
        NavigationView {
            DetailHealthcheckView(healthcheck: hcd, isEdit: .constant(false))
        }
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode")
    }
}
