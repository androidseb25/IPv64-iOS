//
//  LogView.swift
//  IPv64
//
//  Created by Sebastian Rank on 25.11.22.
//

import SwiftUI

struct LogView: View {
    
    @ObservedObject var api: NetworkServices = NetworkServices()
    @State var myLogs: Logs = Logs(logs: [])
    @State var activeSheet: ActiveSheet? = nil
    @State var errorTyp: ErrorTyp? = .none
    
    var body: some View {
        ZStack {
            VStack {
                Form {
                    Section("Letzten 10 Logs") {
                        let logList = (myLogs.logs ?? []).prefix(10)
                        ForEach(logList, id: \.id) { log in
                            LogItemView(log: log)
                        }
                    }
                }
            }
            .sheet(item: $activeSheet) { item in
                showActiveSheet(item: item)
            }
            
            if api.isLoading {
                VStack() {
                    Spinner(isAnimating: true, style: .large, color: .white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.3).ignoresSafeArea())
            }
        }
        .onAppear {
            GetLogs()
        }
        .navigationTitle("Logs")
    }
    
    fileprivate func GetLogs() {
        Task {
            myLogs = await api.GetLogs() ?? Logs(logs: [])
        }
    }
    
    @ViewBuilder
    func showActiveSheet(item: ActiveSheet?) -> some View {
        switch item {
        case .error:
            ErrorSheetView(errorTyp: $errorTyp, deleteThisDomain: .constant(false))
                .interactiveDismissDisabled(errorTyp?.status == 202 ? false : true)
                .onDisappear {
                    if (errorTyp?.status == 401) {
                        SetupPrefs.setPreference(mKey: "APIKEY", mValue: "")
                    } else {
                        GetLogs()
                    }
                }
        default:
            EmptyView()
        }
    }
}

struct LogView_Previews: PreviewProvider {
    static var previews: some View {
        LogView()
    }
}
