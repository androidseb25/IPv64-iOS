//
//  NotificationView.swift
//  IPv64
//
//  Created by Sebastian Rank on 20.10.25.
//

import SwiftUI

struct NotificationView: View {
    
    @Binding var popToRootTab: Tabs
    @StateObject private var api = ApiService()
    
    @State private var integrationResult: IntegrationResult = .empty
    
    @State private var loadedAt: Date?
    @State private var loadID: UUID?
    private var isRefreshing: Bool { loadID != nil }
    @State private var alertType: AlertType?
    @State private var apiErrorMessage: String = ""
    
    var body: some View {
            if #available(iOS 26.0, *) {
                listView
                    .setColorGradient(.orange)
            } else {
                listView
            }
    }
    
    private var listView: some View {
        List {
            ForEach(integrationResult.integrations, id: \.id) { integration in
                NotificationItemView(integration: integration)
            }
        }
        .showLoading(.constant(api.isLoading))
        .apiErrors(api)
        .navigationTitle(Tabs.notification.labelNew)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await reload() }
        .task { if loadedAt == nil || loadedAt!.timeIntervalSinceNow < -30 { await reload() } }
        .overlay {
            if integrationResult.integrations.isEmpty && !api.isLoading {
                ContentUnavailableView("No notification methods", systemImage: "bell", description: Text("Configure notification methods in your IPv64.net account."))
            }
        }
        .alert(item: $alertType) { type in
            switch type {
            case .apiError:
                return Alert(title: Text("Something went wrong."), message: Text("Something went wrong with the API. Please try again later. \n\n\(apiErrorMessage)"), dismissButton: .cancel(Text("OK")))
            default:
                return Alert(title: Text(""))
            }
        }
    }
    
    private func reload() async {
        let requestID = UUID()
        loadID = requestID
        defer { if loadID == requestID { loadID = nil } }
        guard var result = await api.GetIntegrations(), !Task.isCancelled, loadID == requestID else { return }
        result.integrations.sort { $0.integrationName.localizedCaseInsensitiveCompare($1.integrationName) == .orderedAscending }
        integrationResult = result
        loadedAt = .now
    }
}

#Preview { NavigationStack { NotificationView(popToRootTab: .constant(.notification)) } }
