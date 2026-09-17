//
//  HealthcheckNewView.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 30.10.25.
//

import SwiftUI

struct HealthcheckNewView: View {
    
    @Environment(\.dismiss) var dismiss
    
    @Binding var isChanged: Bool
    
    @StateObject private var api = ApiService()
    
    @State private var selectedUnit: Unit = .minute
    @State private var unitList = Unit.minute.list
    @State private var hcName: String = ""
    @State private var alarmCount: Double = 30
    
    @State private var alertType: AlertType?
    @State private var apiErrorMessage: String = ""
    
    var body: some View {
        NavigationStack {
            List {
                Section("Name of Healthcheck") {
                    TextField("eg.: Healthcheck #002", text: $hcName)
                        .lineLimit(1)
                        .autocorrectionDisabled(true)
                }
                Slider(value: $alarmCount, in: 1...60, step: 1.0)
                Section("Unit") {
                    Picker(selection: $selectedUnit, label: Text("\(alarmCount, specifier: "%.0f")")
                        .font(.system(.callout))
                        .padding(.horizontal, 5)) {
                            ForEach(unitList, id: \.self) { un in
                                Text(un.label)
                                    .tag(un)
                            }
                        }
                }
            }
            .navigationTitle(Text("New Healthcheck"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar{
                ToolbarItem{
                    if #available(iOS 26.0, *) {
                        Button(role: .confirm, action: {
                            PostHealthcheck()
                        }) {
                            Label("Save", systemImage: "paperplane")
                        }
                        .tint(.orange)
                        .disabled(hcName.isEmpty)
                    } else {
                        Button(action: {
                            PostHealthcheck()
                        }) {
                            Label("Save", systemImage: "paperplane")
                        }
                        .tint(.orange)
                        .disabled(hcName.isEmpty)
                    }
                }
            }
        }
        .showLoading($api.isLoading)
        .alert(item: $alertType) { type in
            switch type {
            case .apiError:
                return Alert(title: Text("Something went wrong."), message: Text("Something went wrong with the API. Please try again later. \n\n\(apiErrorMessage)"), dismissButton: .cancel(Text("OK")))
            case .apiSuccess:
                return Alert(title: Text("Successfully created!"), message: Text("Your Healthcheck has been created."), dismissButton: .cancel(Text("OK")) {
                    isChanged = true
                    dismiss()
                })
            default:
                return Alert(title: Text(""))
            }
        }
    }
    
    private func PostHealthcheck() {
        Task {
            if let res = await api.PostHealthcheck(add_healthcheck: hcName, alarm_count: Int(alarmCount.rounded()), alarm_unit: selectedUnit.id) {
                if (!res.status.contains("201")) {
                    apiErrorMessage = res.status
                    alertType = .apiError
                } else {
                    alertType = .apiSuccess
                }
            }
        }
    }
}

#Preview {
    HealthcheckNewView(isChanged: .constant(false))
}
