//
//  HealthcheckView.swift
//  IPv64
//
//  Created by Sebastian Rank on 16.01.23.
//

import SwiftUI

struct HealthcheckView: View {
    
    @AppStorage("AccountInfos") var accountInfos: String = ""
    @ObservedObject var api: NetworkServices = NetworkServices()
    
    @State var activeSheet: ActiveSheet? = nil
    @State var errorTyp: ErrorTyp? = .none
    @State var showSheet = false
    @State var deleteThisHealth = false
    @State var healthcheckList: HealthCheckResult? = nil
    
    @State var activeCount = 0
    @State var warningCount = 0
    @State var alarmCount = 0
    @State var pausedCount = 0
    
    @State var deleteHealth = ""
    @State var startPauseHealthToken = ""
    
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
                            ForEach((healthcheckList?.domain.sorted { $0.healthcheckDomain.lowercased() < $1.healthcheckDomain.lowercased() }) ?? [], id: \.healthcheckDomain) { healthCheckDomain in
                                HStack {
                                    Image(systemName: "circle.fill")
                                        .resizable()
                                        .scaledToFill()
                                        .foregroundColor(SetDotColor(statusId: healthCheckDomain.healthstatus!))
                                        .frame(width: 8, height: 8)
                                    Text(healthCheckDomain.healthcheckDomain)
                                    Spacer()
                                    HStack(spacing: 3) {
                                        let lastXPills = GetLastXMonitorPills(count: 8, domain: healthCheckDomain).reversed()
                                        ForEach(lastXPills, id:\.self) { color in
                                            RoundedRectangle(cornerRadius: 5).fill(color)
                                                .frame(width: 5, height: 20)
                                        }
                                    }
                                    .padding(.trailing, 5)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive, action: {
                                        deleteHealth = healthCheckDomain.healthcheckDomain
                                        deleteHealthcheck()
                                    }) {
                                        Label("Löschen", systemImage: "trash")
                                    }
                                    .tint(.red)
                                    if (healthCheckDomain.healthstatus != StatusTypes.pause.statusId) {
                                        Button(role: .destructive, action: {
                                            startPauseHealthToken = ""
                                        }) {
                                            Label("Pause", systemImage: "pause.circle")
                                        }
                                        .tint(.teal)
                                    }
                                    if (healthCheckDomain.healthstatus == StatusTypes.pause.statusId) {
                                        Button(role: .destructive, action: {
                                            startPauseHealthToken = ""
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
            }
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
            activeCount = 0
            warningCount = 0
            alarmCount = 0
            pausedCount = 0
            GetHealthChecks()
        }
    }
    
    @ViewBuilder
    func showActiveSheet(item: ActiveSheet?) -> some View {
        switch item {
        case .add:
            NewHealthcheckView()
        case .error:
            ErrorSheetView(errorTyp: $errorTyp, deleteThisDomain: $deleteThisHealth)
                .interactiveDismissDisabled(errorTyp?.status == 202 ? false : true)
                .onDisappear {
                    if (deleteThisHealth) {
                        Task {
                            print(deleteHealth)
                            let res = await api.DeleteHealth(health: deleteHealth)
                            print(res)
                            activeCount = 0
                            warningCount = 0
                            alarmCount = 0
                            pausedCount = 0
                            GetHealthChecks()
                        }
                    } else {
                        if (errorTyp?.status == 401) {
                            SetupPrefs.setPreference(mKey: "APIKEY", mValue: "")
                        } else {
                            activeCount = 0
                            warningCount = 0
                            alarmCount = 0
                            pausedCount = 0
                            GetHealthChecks()
                        }
                    }
                }
        default:
            EmptyView()
        }
    }
    
    fileprivate func GetHealthChecks() {
        Task {
            healthcheckList = await api.GetHealthchecks()
            let status = healthcheckList?.status
            if (status == nil) {
                throw NetworkError.NoNetworkConnection
            }
            if (!status!.contains("401") && healthcheckList?.domain.count == 0) {
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
                    Array((healthcheckList?.domain.sorted { $0.healthcheckDomain.lowercased() < $1.healthcheckDomain.lowercased() })!).forEach { healthCheckDomain in
                        if (healthCheckDomain.healthstatus == StatusTypes.active.statusId) {
                            activeCount += 1
                        } else if (healthCheckDomain.healthstatus == StatusTypes.warning.statusId) {
                            warningCount += 1
                        } else if (healthCheckDomain.healthstatus == StatusTypes.alarm.statusId) {
                            alarmCount += 1
                        } else if (healthCheckDomain.healthstatus == StatusTypes.pause.statusId) {
                            pausedCount += 1
                        }
                    }
                }
            }
        }
    }
    
    fileprivate func GetLastXMonitorPills(count: Int, domain: HealthCheck) -> [Color] {
        
        let lastEvents = domain.events.suffix(count)
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
