//
//  HealthcheckEditView.swift
//  IPv64.net
//
//  Created by Sebastian Rank on 03.11.25.
//

import SwiftUI

struct HealthcheckEditView: View {
    
    @Environment(\.colorScheme) var systemColorScheme
    @Environment(\.dismiss) var dismiss
    
    @State var hc: HealthCheck
    @Binding var isChanged: Bool
    
    @StateObject private var api = ApiService()
    
    @State private var unitList = Unit.minute.list
    @State private var hcName: String = ""
    @State private var alarmCount: Double = 1.0
    @State private var alarmUnit: Unit = .minute
    @State private var graceCount: Double = 1.0
    @State private var graceUnit: Unit = .minute
    @State private var alarmUp: Bool = false
    @State private var alarmDown: Bool = false
    @State private var integrationIds: String = ""
    
    @State private var alertType: AlertType?
    @State private var apiErrorMessage: String = ""
    
    @State private var showEditIntegragtionMethods: Bool = false
    
    var body: some View {
        NavigationStack {
            listView
        }
    }
    
    private var listView: some View {
        List {
            Section("Name of Healthcheck") {
                TextField("eg.: Healthcheck #002", text: $hcName)
                    .lineLimit(1)
                    .autocorrectionDisabled(true)
            }
            Section("Alarm period") {
                Slider(value: $alarmCount, in: 1...60, step: 1.0)
                Picker(selection: $alarmUnit, label: Text("\(alarmCount, specifier: "%.0f")")
                    .font(.system(.callout))
                    .padding(.horizontal, 5)) {
                        ForEach(unitList, id: \.self) { un in
                            Text(un.label)
                                .tag(un.id)
                        }
                    }
            }
            Section("Grace period") {
                Slider(value: $graceCount, in: 1...60, step: 1.0)
                Picker(selection: $graceUnit, label: Text("\(graceCount, specifier: "%.0f")")
                    .font(.system(.callout))
                    .padding(.horizontal, 5)) {
                        ForEach(unitList, id: \.self) { un in
                            Text(un.label)
                                .tag(un.id)
                        }
                    }
            }
            Section("Notification") {
                Toggle("Notification UP", isOn: $alarmUp)
                    .tint(.green)
                Toggle("Notification DOWN", isOn: $alarmDown)
                    .tint(.red)
                Button(action: {
                    withAnimation {
                        showEditIntegragtionMethods.toggle()
                    }
                }) {
                    Text("Edit Notification methods")
                }
            }
        }
        .showLoading($api.isLoading)
        .onAppear {
            hcName = hc.name
            alarmCount = Double(hc.alarm_count)
            alarmUnit = hc.AlarmUnit
            graceCount = Double(hc.grace_count)
            graceUnit = hc.GraceUnit
            alarmUp = hc.IsAlarmUp
            alarmDown = hc.IsAlarmDown
            integrationIds = hc.integration_id
        }
        .navigationTitle("Edit Healthcheck")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem{
                if #available(iOS 26.0, *) {
                    Button(role: .confirm, action: {
                        withAnimation {
                            PostEditHealthcheck()
                        }
                    }) {
                        Label("Save", systemImage: "paperplane")
                    }
                    .tint(.orange)
                    .disabled(hcName.isEmpty)
                } else {
                    Button(action: {
                        withAnimation {
                            PostEditHealthcheck()
                        }
                    }) {
                        Label("Save", systemImage: "paperplane")
                    }
                    .tint(.orange)
                    .disabled(hcName.isEmpty)
                }
            }
        }
        .alert(item: $alertType) { type in
            switch type {
            case .apiError:
                return Alert(title: Text("Something went wrong."), message: Text("Something went wrong with the API. Please try again later. \n\n\(apiErrorMessage)"), dismissButton: .cancel(Text("OK")))
            case .apiSuccess:
                return Alert(title: Text("Successfully updated!"), message: Text("Your Healthcheck has been updated."), dismissButton: .cancel(Text("OK")) {
                    isChanged = true
                    dismiss()
                })
            default:
                return Alert(title: Text(""))
            }
        }
        .sheet(isPresented: $showEditIntegragtionMethods.animation()){
            HealthcheckIntegrationView(integrationIds: $integrationIds)
        }
    }
    
    private func PostEditHealthcheck() {
        Task {
            var editHc = HealthCheck.empty
            editHc.name = hcName
            editHc.alarm_count = Int(alarmCount.rounded())
            editHc.alarm_unit = alarmUnit.id
            editHc.grace_count = Int(graceCount.rounded())
            editHc.grace_unit = graceUnit.id
            editHc.alarm_up = alarmUp ? 1 : 0
            editHc.alarm_down = alarmDown ? 1 : 0
            editHc.integration_id = integrationIds
            editHc.healthtoken = hc.healthtoken
            if let res = await api.PostEditHealthcheck(healthcheck: editHc) {
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
    HealthcheckEditView(hc: .empty, isChanged: .constant(false))
}
