//
//  HealthcheckView.swift
//  IPv64
//
//  Created by Sebastian Rank on 20.10.25.
//

import SwiftUI
import TipKit
import WidgetKit

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
    
    @State private var search = ""
    @State private var statusFilter = 0
    @State private var loadID: UUID?
    private var isRefreshing: Bool { loadID != nil }
    @State private var loadedAt: Date?
    @State private var reloadVersion = 0

    private var visibleChecks: [HealthCheck] {
        healthcheckResult.domain.filter {
            (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search))
                && (statusFilter == 0 || $0.healthstatus == statusFilter)
        }
    }

    let inlineActionTip = HcActionTip()
    
    var body: some View {
            if #available(iOS 26.0, *) {
                listView
                    .setColorGradient(showNewHealthcheckSheet ? .clear : .orange)
            } else {
                listView
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
                ForEach(visibleChecks, id: \.healthtoken) { hc in
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
         .overlay {
            if healthcheckResult.domain.isEmpty && isRefreshing { ProgressView("Loading healthchecks…") }
            else if visibleChecks.isEmpty {
                ContentUnavailableView {
                    Label(search.isEmpty && statusFilter == 0 ? "No healthchecks" : "No matching healthchecks", systemImage: "bolt.heart")
                } description: {
                    Text(loadedAt == nil ? "Connect to the internet and try again." : "Add a healthcheck or adjust your filters.")
                } actions: {
                    if loadedAt == nil { Button("Retry") { reloadVersion += 1 } }
                    else { Button("Add healthcheck") { showNewHealthcheckSheet = true } }
                }
            }
        }
        .searchable(text: $search, prompt: "Search healthchecks")
        .apiErrors(api)
        .navigationTitle(Tabs.healthcheck.labelNew)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: HealthCheck.self) { hc in
            HealthcheckDetailView(hc: hc, isChanged: $isHealthcheckChanged)
        }
        .toolbar {
            ToolbarItem {
                Menu {
                    Picker("Status", selection: $statusFilter) {
                        Text("All").tag(0)
                        ForEach([Status.active, .pause, .warning, .alarm], id: \.id) { status in
                            Text(status.label).tag(status.id)
                        }
                    }
                } label: { Label("Filter healthchecks", systemImage: "line.3.horizontal.decrease") }
                .tint(systemColorScheme == .dark ? .white : .black)
            }
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
        .refreshable { await reload() }
        .task(id: reloadVersion) {
            if loadedAt == nil || loadedAt!.timeIntervalSinceNow < -30 { await reload() }
        }
        .onChange(of: isHealthcheckChanged) { _, changed in
            if changed { loadedAt = nil; reloadVersion += 1 }
        }
        .overlay(alignment: .bottom) {
            TipView(inlineActionTip)
                .padding()
        }
        .sheet(isPresented: $showNewHealthcheckSheet.animation()){
            HealthcheckNewView(isChanged: $isHealthcheckChanged)
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
                    loadedAt = nil
                    reloadVersion += 1
                })
            case .apiSuccessUpdate:
                return Alert(title: Text("Successfully \(selectedHc.HealthStatus == .pause ? "paused" : "started")!"), message: Text("Your healthcheck has been successfully \(selectedHc.HealthStatus == .pause ? "paused" : "started")."), dismissButton: .cancel(Text("OK")) {
                    loadedAt = nil
                    reloadVersion += 1
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
    
    private func reload() async {
        let requestID = UUID()
        loadID = requestID
        defer { if loadID == requestID { loadID = nil } }
        guard var result = await api.GetHealthchecks(), !Task.isCancelled, loadID == requestID else { return }
        let now = DateFormatter.db.string(from: .now)
        result.domain = result.domain.map { check in
            var check = check
            if check.HealthStatus == .pause {
                check.events.insert(HealthEvents(event_time: now, status: Status.pause.id, text: "Pause active"), at: 0)
            }
            return check
        }.sorted(by: \.name)
        healthcheckResult = result
        let counts = result.domain.reduce(into: [Int: Int]()) { $0[$1.healthstatus, default: 0] += 1 }
        activeCount = counts[1, default: 0]
        pausedCount = counts[2, default: 0]
        warningCount = counts[3, default: 0]
        alarmCount = counts[4, default: 0]
        loadedAt = .now
        isHealthcheckChanged = false
        WidgetHealthCacheStore.write(checks: result.domain)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
#Preview { NavigationStack { HealthcheckView(popToRootTab: .constant(.healthcheck)) } }
