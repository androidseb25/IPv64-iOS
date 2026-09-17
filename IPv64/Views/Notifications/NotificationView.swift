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
    
    @State private var alertType: AlertType?
    @State private var apiErrorMessage: String = ""
    
    var body: some View {
        NavigationStack {
            if #available(iOS 26.0, *) {
                listView
                    .setColorGradient(.orange)
            } else {
                listView
            }
        }
    }
    
    private var listView: some View {
        List {
            ForEach(integrationResult.integrations.sorted(by: \.integrationName), id: \.id) { integration in
                NotificationItemView(integration: integration)
            }
        }
        .showLoading($api.isLoading)
        .navigationTitle(Tabs.notification.labelNew)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            GetIntegrations()
        }
        .onAppear {
            GetIntegrations()
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
    
    private func GetIntegrations() {
        Task {
            if let res = await api.GetIntegrations() {
                if (res.status.contains("200")) {
                    integrationResult = res
                } else {
                    apiErrorMessage = "\(res.status)\n\(res.info)"
                    alertType = .apiError
                }
            }
        }
    }
}

#Preview {
    NotificationView(popToRootTab: .constant(.notification))
}
