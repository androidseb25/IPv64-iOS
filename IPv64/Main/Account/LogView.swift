//
//  LogView.swift
//  IPv64
//
//  Created by Sebastian Rank on 25.11.22.
//

import SwiftUI

struct LogView: View {
    
    @ObservedObject var api: NetworkServices = NetworkServices()
    @State var myLogs: [MyLogs] = []
    @State var activeSheet: ActiveSheet? = nil
    @State var errorTyp: ErrorTyp? = .none
    @State private var showAllLogs = false
    @State private var btnTxt = ""
    @State private var myCustomLogs: [MyLogs] = []
    
    var body: some View {
        ZStack {
            VStack {
                Form {
                    Section("Letzten \(myCustomLogs.count) Logs") {
                        ForEach(myCustomLogs, id: \.id) { log in
                            LogItemView(log: log)
                        }
                    }
                    
                    Button(action: {
                        withAnimation {
                            showAllLogs.toggle()
                            editLogs()
                        }
                    }) {
                        Text(btnTxt)
                            .font(.system(.callout, design: .rounded))
                            .textCase(.uppercase)
                            .foregroundColor(Color("ip64_color"))
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
    
    fileprivate func editLogs() {
        if (showAllLogs) {
            btnTxt = "Zeige 10 Logs an"
            myCustomLogs = myLogs
        } else {
            btnTxt = "Zeige \(myLogs.count) Logs an"
            myCustomLogs = Array(myLogs.prefix(10))
        }
    }
    
    fileprivate func GetLogs() {
        Task {
            myLogs = await api.GetLogs()?.logs ?? Logs(logs: []).logs!
            editLogs()
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

#Preview {
    LogView()
}
