//
//  HealthcheckIntegrationView.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 03.11.25.
//

import SwiftUI

struct HealthcheckIntegrationView: View {
    
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var api = ApiService()
    
    @Binding var integrationIds: String
    
    @State private var integrationResult: IntegrationResult = .empty
    
    @State private var alertType: AlertType?
    @State private var apiErrorMessage: String = ""
    
    var body: some View {
        NavigationStack {
            listView
        }
    }
    
    private var listView: some View {
        List {
            Section {
                ForEach(integrationResult.integrations.sorted(by: \.integrationName), id: \.id) { integration in
                    Toggle(integration.integrationName, isOn: Binding(
                        get: { integration.selectedState },
                        set: { newValue in
                            integrationResult.integrations = integrationResult.integrations.map{ integ in
                                var i = integ
                                if (i.integrationId == integration.integrationId) {
                                    i.selectedState = newValue
                                }
                                return i
                            }
                        }
                    ))
                }
            }
        }
        .showLoading($api.isLoading)
        .onAppear {
            GetIntegrations()
        }
        .navigationTitle("Notification methods")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem{
                if #available(iOS 26.0, *) {
                    Button(role: .confirm, action: {
                        withAnimation {
                            integrationIds = integrationResult.integrations
                                .filter { $0.selectedState }
                                .compactMap { $0.integrationId }          // entfernt nils
                                .map(String.init)                         // konvertiert Int → String
                                .joined(separator: ",")
                            dismiss()
                        }
                    }) {
                        Label("Save", systemImage: "paperplane")
                    }
                    .tint(.orange)
                } else {
                    Button(action: {
                        withAnimation {
                            integrationIds = integrationResult.integrations
                                .filter { $0.selectedState }
                                .compactMap { $0.integrationId }          // entfernt nils
                                .map(String.init)                         // konvertiert Int → String
                                .joined(separator: ",")
                            dismiss()
                        }
                    }) {
                        Label("Save", systemImage: "paperplane")
                    }
                    .tint(.orange)
                }
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
    
    private func GetIntegrations() {
        Task {
            if var res = await api.GetIntegrations() {
                if (res.status.contains("200")) {
                    res.integrations = res.integrations.map { integration in
                        var i = integration
                        if (integrationIds.contains("\(integration.integrationId, default: "-1")")) {
                            i.selectedState = true
                        }
                        return i
                    }
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
    HealthcheckIntegrationView(integrationIds: .constant(""))
}
