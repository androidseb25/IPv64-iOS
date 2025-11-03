//
//  HealthcheckView.swift
//  IPv64
//
//  Created by Sebastian Rank on 20.10.25.
//

import SwiftUI
import TipKit

struct HealthcheckView: View {
    
    @Environment(\.colorScheme) var systemColorScheme
    
    @Binding var popToRootTab: Tabs
    @StateObject private var api = ApiService()
    
    @State private var columnsGrid: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)
    
    @State private var healthcheckResult: HealthCheckResult = .empty
    @State private var selectedHc: HealthCheck = .empty
    @State private var alertType: AlertType?
    @State private var apiErrorMessage: String = ""
    @State private var activeCount = 0
    @State private var warningCount = 0
    @State private var alarmCount = 0
    @State private var pausedCount = 0
    @State private var showNewHealthcheckSheet: Bool = false
    @State private var isHealthcheckChanged: Bool = false
    
    let inlineActionTip = HcActionTip()
    
    var body: some View {
        NavigationStack {
            if #available(iOS 26.0, *) {
                listView
                    .setColorGradient(showNewHealthcheckSheet ? .clear : .orange)
            } else {
                listView
            }
        }
    }
    
    private var listView: some View {
        List {
            LazyVGrid(columns: columnsGrid, spacing: 10) {
                HealthcheckStatistikItem(status: Status.active, count: $activeCount)
                HealthcheckStatistikItem(status: Status.warning, count: $warningCount)
                HealthcheckStatistikItem(status: Status.alarm, count: $alarmCount)
                HealthcheckStatistikItem(status: Status.pause, count: $pausedCount)
            }
            .padding()
            .listStyle(.plain)
            .listRowInsets(EdgeInsets(top: -16, leading: -16, bottom: -16, trailing: -16))
            .listRowBackground(Color.clear)
            
            Section {
                ForEach(healthcheckResult.domain.sorted(by: \.name), id: \.healthtoken) { hc in
                    NavigationLink(value: hc) {
                        HealthcheckItemView(healthcheck: hc)
                            .tag(hc.healthtoken)
                            .swipeActions {
                                if (hc.HealthStatus == .pause) {
                                    Button {
                                        withAnimation {
                                            selectedHc = hc
                                            selectedHc.healthstatus = 1
                                            StartPauseHealthcheck(startPause: "start_healthcheck", hcToken: selectedHc.healthtoken)
                                        }
                                    } label: {
                                        Label("Start", systemImage: "play")
                                    }
                                    .tint(.green)
                                } else {
                                    Button {
                                        withAnimation {
                                            selectedHc = hc
                                            selectedHc.healthstatus = 2
                                            StartPauseHealthcheck(startPause: "pause_healthcheck", hcToken: selectedHc.healthtoken)
                                        }
                                    } label: {
                                        Label("Pause", systemImage: "pause")
                                    }
                                    .tint(.teal)
                                }
                                Button {
                                    selectedHc = hc
                                    alertType = .deleteHc
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(.red)
                            }
                    }
                }
            }
        }
        .showLoading($api.isLoading)
        .navigationTitle(Tabs.healthcheck.labelNew)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: HealthCheck.self) { hc in
            HealthcheckDetailView(hc: hc, isChanged: $isHealthcheckChanged)
        }
        .toolbar {
            ToolbarItem {
                Button(action: {
                    withAnimation {
                        showNewHealthcheckSheet.toggle()
                    }
                }){
                    Label("Add", image: "bolt.heart.badge.plus")
                }
                .tint(systemColorScheme == .dark ? .white : .black)
            }
        }
        .refreshable {
            GetHealthchecks()
        }
        .onAppear {
            GetHealthchecks()
        }
        .overlay(alignment: .bottom) {
            TipView(inlineActionTip)
                .padding()
        }
        .sheet(isPresented: $showNewHealthcheckSheet.animation()){
            HealthcheckNewView(isChanged: $isHealthcheckChanged).onDisappear {
                if (isHealthcheckChanged) {
                    isHealthcheckChanged = false
                    GetHealthchecks()
                }
            }
        }
        .alert(item: $alertType) { type in
            switch type {
            case .deleteHc:
                return Alert(
                    title: Text("Are you sure you want to delete this healtchcheck?"),
                    message: Text("You can't undo this action. This will permanently delete the healthcheck from your account."),
                    primaryButton: .destructive(Text("Yes")) {
                        withAnimation {
                            DeleteHealthcheck(hcToken: selectedHc.healthtoken)
                        }
                    },
                    secondaryButton: .cancel() {  }
                )
            case .apiError:
                return Alert(title: Text("Something went wrong."), message: Text("Something went wrong with the API. Please try again later. \n\n\(apiErrorMessage)"), dismissButton: .cancel(Text("OK")))
            case .apiSuccessDelete:
                return Alert(title: Text("Successfully deleted!"), message: Text("Your healthcheck has been successfully deleted."), dismissButton: .cancel(Text("OK")) {
                    GetHealthchecks()
                })
            case .apiSuccessUpdate:
                return Alert(title: Text("Successfully \(selectedHc.HealthStatus == .pause ? "paused" : "started")!"), message: Text("Your healthcheck has been successfully \(selectedHc.HealthStatus == .pause ? "paused" : "started")."), dismissButton: .cancel(Text("OK")) {
                    GetHealthchecks()
                })
            default:
                return Alert(title: Text(""))
            }
        }
    }
    
    private func DeleteHealthcheck(hcToken: String) {
        Task {
            if let res = await api.DeleteHealthcheck(hcToken: hcToken) {
                if (!res.status.contains("202")) {
                    apiErrorMessage = res.status
                    alertType = .apiError
                } else {
                    alertType = .apiSuccessDelete
                }
            }
        }
    }
    
    private func StartPauseHealthcheck(startPause: String, hcToken: String) {
        Task {
            if let res = await api.PostStartPauseHealthcheck(startPause: startPause, hcToken: hcToken) {
                if (!res.status.contains("200")) {
                    apiErrorMessage = res.status
                    alertType = .apiError
                } else {
                    alertType = .apiSuccessUpdate
                }
            }
        }
    }
    
    private func GetHealthchecks() {
        Task {
            if var res = await api.GetHealthchecks() {
                if (res.status.contains("200")) {
                    let df = DateFormatter()
                    df.calendar = Calendar(identifier: .gregorian)
                    df.locale = Locale(identifier: "en_US_POSIX")
                    df.timeZone = TimeZone(identifier: "Europe/Berlin")
                    df.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    
                    let nowString = df.string(from: Date())
                    
                    let newEvent = HealthEvents(event_time: nowString, status: Status.pause.id, text: "Pause active")
                    res.domain = res.domain.map { hc in
                        var h = hc
                        if h.HealthStatus == .pause {
                            h.events.insert(newEvent, at: 0)
                            print(h.events)
                        }
                        return h
                    }
                    healthcheckResult = res
                    activeCount = healthcheckResult.domain.filter( { $0.HealthStatus == .active }).count
                    warningCount = healthcheckResult.domain.filter( { $0.HealthStatus == .warning }).count
                    alarmCount = healthcheckResult.domain.filter( { $0.HealthStatus == .alarm }).count
                    pausedCount = healthcheckResult.domain.filter( { $0.HealthStatus == .pause }).count
                } else {
                    apiErrorMessage = "\(res.status)\n\(res.info)"
                    alertType = .apiError
                }
                isHealthcheckChanged = false
            }
        }
    }
}
#Preview {
    HealthcheckView(popToRootTab: .constant(.healthcheck))
}
