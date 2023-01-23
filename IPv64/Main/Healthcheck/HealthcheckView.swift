//
//  HealthcheckView.swift
//  IPv64
//
//  Created by Sebastian Rank on 16.01.23.
//

import SwiftUI
import Introspect

struct HealthcheckView: View {
    
    @AppStorage("AccountInfos") var accountInfos: String = ""
    @AppStorage("HealthcheckList") var healthCheckList: String = ""
    @AppStorage("IntegrationList") var integrationListS: String = ""
    @ObservedObject var api: NetworkServices = NetworkServices()
    
    @State var activeSheet: ActiveSheet? = nil
    @State var errorTyp: ErrorTyp? = .none
    @State var showSheet = false
    @State var deleteThisHealth = false
    @State var healthcheckList: HealthCheckResult? = nil
    @State var integrationList: IntegrationResult? = nil
    
    @State var activeCount = 0
    @State var warningCount = 0
    @State var alarmCount = 0
    @State var pausedCount = 0
    
    @State var deleteHealth = ""
    @State var startPauseHealthToken = ""
    
    @State private var refeshUUID = UUID()
    @State private var isNewItem = false
    
    fileprivate func loadAccountInfos() {
        Task {
            do {
                let response = await api.GetAccountStatus()
                if (response == nil) {
                    throw NetworkError.NoNetworkConnection
                }
                let jsonEncoder = JSONEncoder()
                let jsonData = try jsonEncoder.encode(response)
                let json = String(data: jsonData, encoding: String.Encoding.utf8)
                accountInfos = json!
            } catch let error {
                print(error)
                activeSheet = .error
                errorTyp = ErrorTypes.websiteRequestError
            }
        }
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
    
    fileprivate func deleteHealthcheck() {
        errorTyp = ErrorTypes.deletehealth
        activeSheet = .error
        print(errorTyp)
    }
    
    fileprivate func startPauseHealthCheck(isPause: Bool) {
        Task {
            if (isPause) {
                let res = await api.PostPauseHealth(healthtoken: startPauseHealthToken)
                startPauseHealthToken = ""
                print(res)
            } else {
                let res = await api.PostStartHealth(healthtoken: startPauseHealthToken)
                startPauseHealthToken = ""
                print(res)
            }
            GetHealthChecks()
        }
    }
    
    var body: some View {
        ZStack {
            NavigationView {
                VStack {
                    Form {
                        HealthcheckStatsView(activeCount: $activeCount, warningCount: $warningCount, alarmCount: $alarmCount, pausedCount: $pausedCount)
                            .listStyle(.plain)
                            .listRowInsets(EdgeInsets(top: -15, leading: -15, bottom: -15, trailing: -15))
                            .listRowBackground(Color.clear)
                        
                        Section {
                            if (healthcheckList?.domain.count == 0) {
                                Text("Keine Daten gefunden!")
                            } else {
                                ForEach((healthcheckList?.domain.sorted { $0.name.lowercased() < $1.name.lowercased() }) ?? [], id: \.name) { hcd in
                                    NavigationLink(destination: DetailHealthcheckView(healthcheck: hcd)) {
                                        LazyVStack {
                                            HStack {
                                                Image(systemName: "circle.fill")
                                                    .resizable()
                                                    .scaledToFill()
                                                    .foregroundColor(SetDotColor(statusId: hcd.healthstatus))
                                                    .frame(width: 8, height: 8)
                                                Text(hcd.name)
                                                Spacer()
                                                HStack(spacing: 4) {
                                                    let lastXPills = GetLastXMonitorPills(count: 10, domain: hcd).reversed()
                                                    ForEach(lastXPills, id:\.self) { color in
                                                        RoundedRectangle(cornerRadius: 5).fill(color)
                                                            .frame(width: 5, height: 20)
                                                    }
                                                }
                                                .padding(.trailing, 5)
                                            }
                                            .id(UUID())
                                            .swipeActions(edge: .trailing) {
                                                Button(role: .destructive, action: {
                                                    deleteHealth = hcd.healthtoken
                                                    deleteHealthcheck()
                                                }) {
                                                    Label("Löschen", systemImage: "trash")
                                                }
                                                .tint(.red)
                                                if (hcd.healthstatus != StatusTypes.pause.statusId) {
                                                    Button(role: .destructive, action: {
                                                        startPauseHealthToken = hcd.healthtoken
                                                        startPauseHealthCheck(isPause: true)
                                                    }) {
                                                        Label("Pause", systemImage: "pause.circle")
                                                    }
                                                    .tint(.teal)
                                                }
                                                if (hcd.healthstatus == StatusTypes.pause.statusId) {
                                                    Button(role: .destructive, action: {
                                                        startPauseHealthToken = hcd.healthtoken
                                                        startPauseHealthCheck(isPause: false)
                                                    }) {
                                                        Label("Start", systemImage: "play.circle")
                                                    }
                                                    .tint(.green)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            withAnimation {
                                activeSheet = .add
                            }
                        }) {
                            Image(systemName: "plus.circle")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundColor(Color("primaryText"))
                        }
                        .foregroundColor(.black)
                    }
                }
                .navigationTitle("Healthcheck")
                .refreshable {
                    GetHealthChecks()
                }
            }
            .introspectNavigationController { navigationController in
                navigationController.splitViewController?.preferredPrimaryColumnWidthFraction = 1
                navigationController.splitViewController?.maximumPrimaryColumnWidth = 400
            }
            .id(refeshUUID)
            .accentColor(Color("AccentColor"))
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
        .onAppear {
            GetHealthChecks()
        }
    }
    
    @ViewBuilder
    func showActiveSheet(item: ActiveSheet?) -> some View {
        switch item {
        case .add:
            NewHealthcheckView(newItem: $isNewItem)
                .onDisappear {
                    if (isNewItem) {
                        isNewItem = false
                        GetHealthChecks()
                    }
                }
        case .error:
            ErrorSheetView(errorTyp: $errorTyp, deleteThisDomain: $deleteThisHealth)
                .interactiveDismissDisabled(errorTyp?.status == 202 ? false : true)
                .onDisappear {
                    if (deleteThisHealth) {
                        Task {
                            refeshUUID = UUID()
                            print(deleteHealth)
                            let res = await api.DeleteHealth(health: deleteHealth)
                            print(res)
                            GetHealthChecks()
                        }
                    } else {
                        if (errorTyp?.status == 401) {
                            SetupPrefs.setPreference(mKey: "APIKEY", mValue: "")
                        } else {
                            GetHealthChecks()
                        }
                    }
                }
        default:
            EmptyView()
        }
    }
    
    fileprivate func GetHealthChecks() {
        api.isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            Task {
                activeCount = 0
                warningCount = 0
                alarmCount = 0
                pausedCount = 0
                healthcheckList = await api.GetHealthchecks()
                print(healthcheckList)
                let status = healthcheckList?.status
                if (status == nil) {
                    throw NetworkError.NoNetworkConnection
                }
                if (status!.contains("429") && healthcheckList?.domain.count == 0) {
                    activeSheet = .error
                    errorTyp = ErrorTypes.tooManyRequests
                } else if (status!.contains("401")) {
                    activeSheet = .error
                    errorTyp = ErrorTypes.unauthorized
                } else {
                    activeSheet = nil
                    errorTyp = nil
                    print(healthcheckList)
                    if (healthcheckList != nil) {
                        let jsonEncoder = JSONEncoder()
                        let jsonData = try jsonEncoder.encode(healthcheckList)
                        let json = String(data: jsonData, encoding: String.Encoding.utf8)
                        healthCheckList = json!
                        Array((healthcheckList?.domain.sorted { $0.name.lowercased() < $1.name.lowercased() })!).forEach { hcd in
                            if (hcd.healthstatus == StatusTypes.active.statusId) {
                                activeCount += 1
                            } else if (hcd.healthstatus == StatusTypes.warning.statusId) {
                                warningCount += 1
                            } else if (hcd.healthstatus == StatusTypes.alarm.statusId) {
                                alarmCount += 1
                            } else if (hcd.healthstatus == StatusTypes.pause.statusId) {
                                pausedCount += 1
                            }
                        }
                    }
                    GetIntegrations()
                }
            }
        }
    }
    
    fileprivate func GetIntegrations() {
        Task {
            integrationList = await api.GetIntegrations()
            let status = integrationList?.status
            if (status == nil) {
                throw NetworkError.NoNetworkConnection
            }
            if (status!.contains("429") && integrationList?.integration.count == 0) {
                activeSheet = .error
                errorTyp = ErrorTypes.tooManyRequests
            } else if (status!.contains("401")) {
                activeSheet = .error
                errorTyp = ErrorTypes.unauthorized
            } else {
                activeSheet = nil
                errorTyp = nil
                print(integrationList)
                if (integrationList != nil) {
                    let jsonEncoder = JSONEncoder()
                    let jsonData = try jsonEncoder.encode(integrationList?.integration)
                    let json = String(data: jsonData, encoding: String.Encoding.utf8)
                    integrationListS = json!
                }
            }
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
}

struct HealthcheckView_Previews: PreviewProvider {
    static var previews: some View {
        HealthcheckView()
            .preferredColorScheme(.light)
            .previewDisplayName("Light Mode")
        HealthcheckView()
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
    }
}
