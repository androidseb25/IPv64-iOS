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
    }
    
    private func GetIntegrations() {
        Task {
            if let res = await api.GetIntegrations() {
                integrationResult = res
            }
        }
    }
}

#Preview {
    NotificationView(popToRootTab: .constant(.notification))
}
