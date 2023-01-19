//
//  NewHealthcheckView.swift
//  IPv64
//
//  Created by Sebastian Rank on 16.01.23.
//

import SwiftUI

struct NewHealthcheckView: View {
    
    @Environment(\.presentationMode) var presentationMode
    @Binding var newItem: Bool
    @ObservedObject var api: NetworkServices = NetworkServices()
    @State var activeSheet: ActiveSheet? = nil
    @State var errorTyp: ErrorTyp? = nil
    @State var showSheet = false
    @State var healthName = ""
    @State var healthAlarmCount = 30.0
    @State var healthAlarmUnit = 1
    
    var AlarmUnitList: [AlarmUnit] = [
        AlarmUnitTypes.minutes,
        AlarmUnitTypes.stunden,
        AlarmUnitTypes.tage
    ]
    
    fileprivate func GetUnit() -> String {
        if (healthAlarmUnit == AlarmUnitTypes.minutes.id) {
            return AlarmUnitTypes.minutes.text!
        } else if (healthAlarmUnit == AlarmUnitTypes.stunden.id) {
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
                        Section("Benötigte Informationen") {
                            TextField("Healthcheck #002", text: $healthName)
                            Text("\(Int(healthAlarmCount)) \(GetUnit())")
                            Slider(value: $healthAlarmCount, in: 1...60, step: 1.0)
                            Picker(selection: $healthAlarmUnit, label: Text("Zeitraum")
                                .font(.system(.callout))
                                .padding(.horizontal, 5)) {
                                    ForEach(0 ..< AlarmUnitList.count) {
                                        Text(AlarmUnitList[$0].text!)
                                            .tag(AlarmUnitList[$0].id!)
                                    }
                                }
                        }
                    }
                }
                .navigationTitle("Neuer Healthcheck")
                .sheet(item: $activeSheet) { item in
                    showActiveSheet(item: item)
                }
                .toolbar {
                    ToolbarItem {
                        Button(action: {
                            if (healthName.count > 0) {
                                Task {
                                    let res = await api.PostHealth(add_healthcheck: healthName, alarm_count: Int(healthAlarmCount), alarm_unit: healthAlarmUnit)
                                    print(res)
                                    if (res?.info == "success") {
                                        activeSheet = .error
                                        errorTyp = ErrorTypes.healthcheckCreatedSuccesfully
                                        newItem = true
                                    } else if (res?.info == "error") {
                                        activeSheet = .error
                                    } else if (res?.info == "Updateintervall overcommited") {
                                        activeSheet = .error
                                        errorTyp = ErrorTypes.tooManyRequests
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
                if api.isLoading {
                    VStack() {
                        Spinner(isAnimating: true, style: .large, color: .white)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.3).ignoresSafeArea())
                }
            }
        }
    }
    
    
    @ViewBuilder
    func showActiveSheet(item: ActiveSheet?) -> some View {
        switch item {
        case .add:
            EmptyView()
        case .detail:
            EmptyView()
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

struct NewHealthcheckView_Previews: PreviewProvider {
    static var previews: some View {
        NewHealthcheckView(newItem: .constant(false))
    }
}
