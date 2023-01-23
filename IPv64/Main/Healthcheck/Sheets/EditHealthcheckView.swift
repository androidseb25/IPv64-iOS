//
//  EditHealthcheckView.swift
//  IPv64
//
//  Created by Sebastian Rank on 21.01.23.
//

import SwiftUI

struct EditHealthcheckView: View {
    
    @Environment(\.presentationMode) var presentationMode
    @AppStorage("IntegrationList") var integrationListS: String = ""
    
    @ObservedObject var api: NetworkServices = NetworkServices()
    @State var activeSheet: ActiveSheet? = nil
    @State var errorTyp: ErrorTyp? = nil
    @State var showSheet = false
    @State var healthcheck: HealthCheck
    @Binding var updatedItem: Bool
    @State var alarmCount = 0.0
    @State var graceCount = 0.0
    @State var notifyDown = false
    @State var notifyUp = false
    
    @State var integrationList: [Integration] = []
    
    var AlarmUnitList: [AlarmUnit] = [
        AlarmUnitTypes.minutes,
        AlarmUnitTypes.stunden,
        AlarmUnitTypes.tage
    ]
    
    fileprivate func GetUnit(unit: Int) -> String {
        if (unit == AlarmUnitTypes.minutes.id) {
            return AlarmUnitTypes.minutes.text!
        } else if (unit == AlarmUnitTypes.stunden.id) {
            return AlarmUnitTypes.stunden.text!
        } else {
            return AlarmUnitTypes.tage.text!
        }
    }
    
    var body: some View {
        ZStack {
            NavigationView {
                VStack {
                    Form {
                        Section("Name") {
                            TextField("Healthcheck #002", text: $healthcheck.name)
                        }
                        Section("Zeitraum") {
                            Text("\(Int(alarmCount)) \(GetUnit(unit: healthcheck.alarm_unit))")
                            Slider(value: $alarmCount, in: 1...60, step: 1.0)
                            Picker(selection: $healthcheck.alarm_unit, label: Text("Zeitraum")) {
                                ForEach(0 ..< AlarmUnitList.count) {
                                    Text(AlarmUnitList[$0].text!)
                                        .tag(AlarmUnitList[$0].id!)
                                }
                            }
                        }
                        Section("Karenzzeit") {
                            Text("\(Int(graceCount)) \(GetUnit(unit: healthcheck.grace_unit))")
                            Slider(value: $graceCount, in: 1...60, step: 1.0)
                            Picker(selection: $healthcheck.grace_unit, label: Text("Zeitraum")) {
                                ForEach(0 ..< AlarmUnitList.count) {
                                    Text(AlarmUnitList[$0].text!)
                                        .tag(AlarmUnitList[$0].id!)
                                }
                            }
                        }
                        Section("Benachrichtigung") {
                            let intList = integrationList
                            Picker(selection: $healthcheck.integration_id, label: Text("Benachrichtungsmethode")) {
                                ForEach(0 ..< intList.count) {
                                    Text(intList[$0].integration_name!)
                                        .tag(intList[$0].integration_id)
                                }
                            }
                            Toggle(isOn: $notifyDown) {
                                Text("Benachrichtung bei DOWN")
                            }.tint(.red)
                            Toggle(isOn: $notifyUp) {
                                Text("Benachrichtung bei UP")
                            }.tint(.green)
                        }
                    }
                }
                .navigationTitle("Bearbeiten")
                .sheet(item: $activeSheet) { item in
                    showActiveSheet(item: item)
                }
                .toolbar {
                    ToolbarItem {
                        Button(action: {
                            if (healthcheck.name.count > 0) {
                                Task {
                                    healthcheck.alarm_count = Int(alarmCount)
                                    healthcheck.grace_count = Int(graceCount)
                                    healthcheck.alarm_down = notifyDown ? 1 : 0
                                    healthcheck.alarm_up = notifyUp ? 1 : 0
                                    let res = await api.PostEditHealthcheck(healthcheck: healthcheck)
                                    print(res)
                                    withAnimation {
                                        if (res?.info == "success") {
                                            activeSheet = .error
                                            errorTyp = ErrorTypes.healthcheckUpdatedSuccesfully
                                            updatedItem = true
                                        } else if (res?.info == "error") {
                                            activeSheet = .error
                                        } else if (res?.info == "Updateintervall overcommited") {
                                            activeSheet = .error
                                            errorTyp = ErrorTypes.tooManyRequests
                                        }
                                    }
                                }
                            }
                        }) {
                            Image(systemName: "paperplane")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundColor(Color("primaryText"))
                        }
                        .foregroundColor(.black)
                    }
                }
            }
            .onAppear {
                alarmCount = Double(healthcheck.alarm_count)
                graceCount = Double(healthcheck.grace_count)
                notifyUp = healthcheck.alarm_up == 1
                notifyDown = healthcheck.alarm_down == 1
                do {
                    let jsonDecoder = JSONDecoder()
                    print(integrationListS)
                    let jsonData = integrationListS.data(using: .utf8)
                    integrationList = try jsonDecoder.decode([Integration].self, from: jsonData!)
                } catch {
                    print("ERROR \(error.localizedDescription)")
                }
            }
            .tint(Color("ip64_color"))
            if api.isLoading {
                VStack() {
                    Spinner(isAnimating: true, style: .large, color: .white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.3).ignoresSafeArea())
            }
        }
    }
    
    
    @ViewBuilder
    func showActiveSheet(item: ActiveSheet?) -> some View {
        switch item {
        case .error:
            ErrorSheetView(errorTyp: $errorTyp, deleteThisDomain: .constant(false))
                .interactiveDismissDisabled(true)
                .onDisappear {
                    if (self.errorTyp!.status == 201) {
                        withAnimation {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
        default:
            EmptyView()
        }
    }
}

struct EditHealthcheckView_Previews: PreviewProvider {
    static var previews: some View {
        EditHealthcheckView(healthcheck: DummyData.Healthcheck, updatedItem: .constant(false))
            .preferredColorScheme(.light)
            .previewDisplayName("Light Mode")
        EditHealthcheckView(healthcheck: DummyData.Healthcheck, updatedItem: .constant(false))
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
    }
}
